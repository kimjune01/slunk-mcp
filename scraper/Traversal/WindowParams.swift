//
//  WindowContext.swift
//  observer-lib
//
//  Created by June Kim on 2024-11-11.
//
import Foundation
import LBAccessibility

public struct WindowParams: Sendable {
    public let accessWindow: ElementProtocol
    public let appName: String
    public let appPid: pid_t
    public let index: Int

    public init(accessWindow: ElementProtocol, appName: String, appPid: pid_t, index: Int) {
        self.accessWindow = accessWindow
        self.appName = appName
        self.appPid = appPid
        self.index = index
    }
}
