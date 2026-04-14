//
//  Logger+Parked.swift
//  parked
//

import OSLog

/// Centralized logging for the app.
enum ParkedLog {
    // REASON: Specified subsystem for unified Console filtering.
    static let subsystem = "com.parked.app"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let repository = Logger(subsystem: subsystem, category: "repository")
    static let geocoding = Logger(subsystem: subsystem, category: "geocoding")
    static let saveSpot = Logger(subsystem: subsystem, category: "saveSpot")
}
