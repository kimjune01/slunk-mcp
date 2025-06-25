@preconcurrency import CoreFoundation
import Foundation

import LBMetrics

/// Provides a safe environment with an asynchronous interface to interact with the accessibility infrastructure.
@available(macOS, introduced: 13.0.0) @globalActor public actor Accessibility {
    /// Executor backing this actor.
    public nonisolated let unownedExecutor = Executor.shared.asUnownedSerialExecutor()
    /// Shared singleton.
    public static let shared = Accessibility()

    /// Singleton initializer.
    private init() {}

    /// Schedules an asynchronous function to execute in this actor's isolated context.
    /// - Parameters:
    ///   - _resultType: Return value type.
    ///   - job: Job to execute.
    /// - Returns: Whatever the job returns in the actor's context.
    public static func run<T: Sendable>(
        resultType _resultType: T.Type = T.self,
        job: @escaping @Accessibility () async throws -> T
    ) async rethrows -> T {
        return try await job()
    }
}

public extension Accessibility {
    /// Manages a dedicated thread on which all client accessibility API calls are performed.
    final class Executor: SerialExecutor, @unchecked Sendable {
        // Strict concurrency checking is explicitly disabled because `Thread` instances are not `Sendable`, however
        // their Objective-C `NSThread` counterparts ar guaranteed to be thread-safe [1]. Therefore and given the
        // general reasonable expectation that a Thread management type should itself be thread-safe, there's absolutely
        // no reason to believe that the Swift type would behave differently.
        //
        // [1]: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/ThreadSafetySummary/ThreadSafetySummary.html

        /// Dedicated thread on which all operations are executed.
        private let thread = Thread(block: run)
        /// Executor's shared singleton.
        public static let shared = Executor()

        /// Singleton initializer.
        private init() {
            thread.start()
        }

        /// Sets up and runs the main loop of the dedicated thread.
        private static func run() {
            Thread.current.name = "dev.genos.LittleBird.Accessibility"
            let runLoop = CFRunLoopGetCurrent()
            // Add an idle event source to the thread's run loop to prevent it from returning and exiting the thread.
            var context = CFRunLoopSourceContext()
            context.copyDescription = { _ in
                let description = "Accessibility idle event source"
                let copy = CFStringCreateCopy(kCFAllocatorDefault, description as CFString)!
                return Unmanaged.passRetained(copy)
            }
            context.perform = { _ in
                Log.error("Accessibility idle event source fired unexpectedly")
                assertionFailure("Accessibility idle event source fired unexpectedly")
            }
            context.version = 0
            let source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context)!
            CFRunLoopAddSource(runLoop, source, .defaultMode)
            CFRunLoopRun()
        }

        /// Performs a synchronous job on this executor's dedicated thread.
        /// - Parameters:
        ///   - _resultType: Type of the job's return value.
        ///   - job: Job to execute.
        /// - Returns: Whatever the job returns on the dedicated thread.
        func perform<T: Sendable>(resultType _resultType: T.Type = T.self, job: @Sendable () -> T) -> T {
            return withoutActuallyEscaping(job) { job in
                let operation = Operation(job: job)
                operation.perform(#selector(Operation<T>.execute), on: thread, with: nil, waitUntilDone: true)
                return operation.result!
            }
        }

        /// Schedules a job to be performed on this executor's dedicated thread.
        /// - Parameters:
        ///   - async: Whether the job should be performed asynchronously.
        ///   - job: Job to perform.
        func perform(async: Bool = true, job: @escaping @Sendable () -> Void) {
            let operation = Operation(job: job)
            operation.perform(#selector(Operation<Void>.execute), on: thread, with: nil, waitUntilDone: !async)
        }

        /// Enqueues a job to be perform in the asynchronous context of this executor.
        /// - Parameter job: Job to be scheduled.
        public func enqueue(_ job: UnownedJob) {
            let operation = Operation(job: { [unowned self] in job.runSynchronously(on: asUnownedSerialExecutor()) })
            operation.perform(#selector(Operation<Void>.execute), on: thread, with: nil, waitUntilDone: false)
        }

        /// Aborts execution if a dynamic strict concurrency verification fails.
        public func checkIsolated() {
            guard Thread.current == thread else {
                Log.error("Accessibility executor context isolation verification failed")
                fatalError("Accessibility executor context isolation verification failed")
            }
        }

        /// Builds an unowned reference to this executor.
        /// - Returns: Built unowned reference.
        public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
            return UnownedSerialExecutor(ordinary: self)
        }
    }
}

extension Accessibility {
    /// Wraps a job to be executed in the context of the ``Accessibility`` global actor.
    private final class Operation<T: Sendable>: NSObject {
        /// Return value of the underlying job.
        var result: T?
        /// Job to be executed.
        private let job: @Sendable () -> T

        /// Creates a new operation ready to execute a job.
        /// - Parameter job: Job to execute.
        init(job: @escaping @Sendable () -> T) {
            self.job = job
            super.init()
        }

        /// Method whose selector is intended to be passed to one of `NSObject`'s `perform` methods to execute the job
        /// on a different thread.
        @objc func execute() {
            guard result == nil else {
                Log.error("Job already executed")
                assertionFailure("Job already executed")
                return
            }
            result = autoreleasepool(invoking: job)
        }
    }
}
