//
//  AppDependencies.swift
//  parked
//

import Foundation
import SwiftData

/// Composition root helpers for `ModelContainer` creation.
enum AppDependencies {
    /// Persistent on-disk SwiftData stack for `ParkingSpot`.
    /// REASON: Nonisolated so `App` init can construct the container without `MainActor` assumptions.
    static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([ParkingSpot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// In-memory container for previews and tests.
    static func makePreviewModelContainer() throws -> ModelContainer {
        let schema = Schema([ParkingSpot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
