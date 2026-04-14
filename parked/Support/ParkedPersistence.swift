//
//  ParkedPersistence.swift
//  parked
//

import SwiftData

/// REASON: `UIApplicationDelegate` and `BGTaskScheduler` handlers need the same `ModelContainer` as SwiftUI; assign once at app launch from `parkedApp`.
enum ParkedPersistence {
    static var sharedContainer: ModelContainer?
}
