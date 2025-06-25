import AppKit
import Foundation

public struct AppState: Sendable, Identifiable, Equatable {
    public let pid: pid_t
    public let name: String
    public let isActive: Bool
    public var id: Int { Int(pid) }

    public init(pid: pid_t, name: String, isActive: Bool = false) {
        self.pid = pid
        self.name = name
        self.isActive = isActive
    }

    public init(runningApplication: NSRunningApplication) {
        self.name = runningApplication.localizedName ?? ""
        self.pid = runningApplication.processIdentifier
        self.isActive = runningApplication.isActive
    }

    static let empty = AppState(pid: 0, name: "", isActive: false)
}