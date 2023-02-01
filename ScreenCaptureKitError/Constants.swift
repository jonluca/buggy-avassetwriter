//
//  Constants.swift
//  ScreenCaptureKitError
//
//  Created by JonLuca De Caro on 1/31/23.
//

import Foundation
import OSLog
struct Constants {
    static let logger = Logger()
    // for recording
    static var excludedApps = [""]
    
    static func rootDirectory() -> URL {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let rootSaveDir = appSupportURL.appendingPathComponent("meetings")
        return rootSaveDir
    }

    static func audioDirectory() -> URL {
        rootDirectory().appendingPathComponent("audio")
    }

    static func ensureDirectory(dir: URL) {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.error("Error creating directory \(dir.path)")
        }
    }
    
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'/'HHmmss"
        formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0) as TimeZone
        return formatter
    }

    static var dateDir: (String, String) {
        let formatter = Constants.dateFormatter
        let now = Date()
        let formatted = formatter.string(from: now).split(separator: "/")
        let dir = String(formatted[0])
        let file = String(formatted[1])
        return (dir, file)
    }
}
