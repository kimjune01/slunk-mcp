@preconcurrency import ApplicationServices

import LBMetrics

/// Observes an accessibility element for events, streaming them to its subscriber.
@Accessibility public final class AccessObserver {
    /// Event stream.
    public let eventStream: AsyncStream<Event>
    /// Legacy accessibility observer.
    private let observer: AXObserver
    /// Legacy accessibility element.
    private let element: AXUIElement
    /// Identity pointer passed as context to the call back function and used to retrieve the event stream sink
    /// associated with this observer from the sink store.
    // This pointer is safe to access and pass around since its value is invariant over this object's lifetime, and we
    // are never dereferencing it.
    private nonisolated(unsafe) let identity: UnsafeMutableRawPointer?
    /// Associative sink store.
    private nonisolated static let sinkStore = SinkStore()

    /// Event handler passed to the underlying AXObserver.
    // Swift doesn't seem to like turning static non-isolated actor methods into C pointers for some reason, so this
    // static closure reference was the best thing I could come up with to ease Amir's mind about a nested non-capturing
    // closure in the initializer.
    private static let callBack: AXObserverCallbackWithInfo = { _, subject, notification, info, identity in
        guard let sink = AccessObserver.sinkStore.getSink(forIdentity: identity) else {
            // Identity is no longer mapped, meaning that its native counterpart has already been destroyed.
            return
        }
        let notification = AccessNotification(rawValue: notification as String)
        // The following hack is necessary since info can be a null pointer but isn't wrapped in an Optional.
        let info = unsafeBitCast(info, to: CFDictionary?.self) as? [String: CFTypeRef] ?? [:]
        let payload = [AccessNotification.PayloadKey: Sendable](uniqueKeysWithValues: info.lazy.map({ (
            key: AccessNotification.PayloadKey(rawValue: $0.key),
            value: swiftConvert(axValue: $0.value)
        ) }))
        let subject = Element(axUIElement: subject)
        let event = Event(notification: notification, subject: subject, payload: payload)
        sink.yield(event)
    }

    /// Creates a new accessibility observer for the specified element.
    /// - Parameter element: Element to observe.
    public init(element: Element) throws {
        self.element = element.element
        let processIdentifier = try element.getProcessIdentifier()
        var observer: AXObserver?
        let result = AXObserverCreateWithInfoCallback(processIdentifier, Self.callBack, &observer)
        let error = AccessError(result)
        guard error == .success, let observer else {
            switch error {
            case .apiDisabled, .notImplemented, .timeout:
                throw error
            default:
                Log.error("Unexpected error creating an accessibility element observer", error: error)
                fatalError("Unexpected error creating an accessibility element observer: \(error)")
            }
        }
        self.observer = observer
        let (eventSource, eventSink) = AsyncStream<Event>.makeStream()
        self.eventStream = eventSource
        identity = Self.sinkStore.storeSink(eventSink)
        let observerSource = AXObserverGetRunLoopSource(observer)
        Accessibility.Executor.shared.perform {
            let runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(runLoop, observerSource, .defaultMode)
        }
    }

    /// Subscribes to be notified of specific state changes of the observed element.
    /// - Parameter notification: Notification to subscribe.
    public func subscribe(to notification: AccessNotification) throws {
        let result = AXObserverAddNotification(observer, element, notification.rawValue as CFString, identity)
        let error = AccessError(result)
        switch error {
        case .success, .notificationAlreadyRegistered:
            break
        case .apiDisabled, .invalidElement, .notificationUnsupported, .timeout:
            throw error
        default:
            Log.error(
                "Unexpected error registering accessibility element notification with identifier \(notification)",
                error: error
            )
            assertionFailure(
                "Unexpected error registering accessibility element notification with identifier \(notification): \(error)"
            )
        }
    }

    /// Unsubscribes from the specified notification of state changes to the observed element.
    /// - Parameter notification: Notification to unsubscribe.
    public func unsubscribe(from notification: AccessNotification) throws {
        let result = AXObserverRemoveNotification(observer, element, notification.rawValue as CFString)
        let error = AccessError(result)
        switch error {
        case .success, .notificationNotRegistered:
            break
        case .apiDisabled, .invalidElement, .notificationUnsupported, .timeout:
            throw error
        default:
            Log.error(
                "Unexpected error unregistering accessibility element notification with identifier \(notification)",
                error: error
            )
            assertionFailure(
                "Unexpected error unregistering accessibility element notification with identifier \(notification): \(error)"
            )
        }
    }

    deinit {
        if let sink = Self.sinkStore.takeSink(forIdentity: identity) {
            sink.finish()
        } else {
            Log.error("Observer stream sink not mapped")
            assertionFailure("Observer stream sink not mapped")
        }
        // Ensuring that the AXObserver is invalidated under the isolated context of the accessibility actor prevents
        // situations in which its being called and destroyed in invalidated in parallel.
        //
        // The scheduling is assynchronous so that the thread where the AccessObserver is being destroyed doesn't have
        // to wait for the accessibility thread to finish its job. This does not cause any race conditions because the
        // AccessObserver instance is never referred back from the call back function.
        Accessibility.Executor.shared.perform(async: true) { [observer] in
            // Perform all the side effects that would normally be performed during the destruction of the AXObserver so
            // it doesn't have anything left to do once it gets destroyed, and make sure that it outlives the whole
            // process to prevent any kind of use after free condition.
            withExtendedLifetime(observer) {
                let eventSource = AXObserverGetRunLoopSource(observer)
                // Prevent this event source from ever firing again.
                CFRunLoopSourceInvalidate(eventSource)
                // Unschedule this event source.
                let runLoop = CFRunLoopGetCurrent()
                CFRunLoopRemoveSource(runLoop, eventSource, .defaultMode)
            }
        }
    }

    /// Maps legacy observers to event stream sink async continuations to be retrieved by the observer's call back
    /// function.
    ///
    //////> Note: Although this interface deals in pointer values, those pointers are only used to store integer values
    /// and are not intended to be reinterpreted or dereferenced.
    private final class SinkStore: @unchecked Sendable {
        // Since the mutability of this type's state is the only real thing making it not Sendable, the correct use of a
        // mutex to prevent concurrent access to values of these types is enough to guarantee thread-safety, making it
        // sound to mark this type as Sendable even if the compiler cannot statically prove that.

        /// Associative backing store.
        private var map = [UnsafeMutableRawPointer?: AsyncStream<Event>.Continuation]()
        /// Incremental identity generator.
        private var generator = UInt.zero
        /// Advisory mutex to guard against concurrent access.
        private let lock = NSLock()

        /// Creates a new store sink.
        init() {}

        /// Stores the provided event stream sink, and creates a new identity that can be used to retrieve it later.
        /// - Parameter sink: Event stream sink.
        /// - Returns: Generated identity pointer, with nil being a valid identity.
        func storeSink(_ sink: AsyncStream<Event>.Continuation) -> UnsafeMutableRawPointer? {
            lock.lock()
            let identity = UnsafeMutableRawPointer(bitPattern: generator)
            // All the systems supported by the MacOS versions targeted by this code have 64-bit linear raw pointers, so
            // providing defensive code to protect against integer overflows seems to be unnecessary given how unlikely
            // it is for that scenario to actually occur in reality. Even if that ever happens, Swift's default
            // controlled crashing behavior is a good enough response.
            generator += 1
            map[identity] = sink
            lock.unlock()
            return identity
        }

        /// Retrieves a copy of the event stream sink associated with the specified identity.
        /// - Parameter identity: Identity pointer returned from an earlier call to ``storeSink(_:)``..
        /// - Returns: Associated event stream sink, if the look up succeeds.
        func getSink(forIdentity identity: UnsafeMutableRawPointer?) -> AsyncStream<Event>.Continuation? {
            lock.lock()
            defer { lock.unlock() }
            return map[identity]
        }

        /// Removes and returns the sink associated with the specified identity.
        func takeSink(forIdentity identity: UnsafeMutableRawPointer?) -> AsyncStream<Event>.Continuation? {
            lock.lock()
            defer { lock.unlock() }
            return map.removeValue(forKey: identity)
        }
    }
}
