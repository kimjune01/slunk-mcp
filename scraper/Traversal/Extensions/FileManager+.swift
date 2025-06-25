//
//  FileManager+.swift
//  observer-lib
//
//  Created by Anton Holub on 06.03.2025.
//

import Foundation
import LBMetrics

public enum LBAppDirectory {
    case recordingsCache

    var path: String {
        switch self {
        case .recordingsCache:
            return "recording_cache"
        }
    }
}

public extension FileManager {
    var applicationSupportAppDirectory: URL? {
        let appSupportDirectory = urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let appBundleId = Bundle.main.bundleIdentifier ?? "com.LittleBird.LBClient-Dev"

        guard let appSupportDirectory else { return nil }

        let appDirectory = appSupportDirectory.appendingPathComponent(appBundleId)

        return appDirectory
    }

    var applicationRecordingCacheDirectory: URL? {
        guard let appDirectory = applicationSupportAppDirectory else { return nil }

        let recordingCacheDirectory = appDirectory.appendingPathComponent(LBAppDirectory.recordingsCache.path)
        do {
            try createDirectoryIfNotExisted(at: recordingCacheDirectory)

            return recordingCacheDirectory
        } catch {
            Log.error(error.localizedDescription, error: error)
            return nil
        }
    }

    func createDirectoryIfNotExisted(at directoryUrl: URL) throws {
        var isDirectory: ObjCBool = true
        let isDirectoryExists = fileExists(atPath: directoryUrl.path(), isDirectory: &isDirectory)

        if !isDirectoryExists {
            try createDirectory(at: directoryUrl, withIntermediateDirectories: true)
            Log.info("Recording cache directory created", category: .controlFlow)
        }
    }
}
