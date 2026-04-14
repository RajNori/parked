//
//  parkedApp.swift
//  parked
//

import OSLog
import SwiftData
import SwiftUI

@main
struct parkedApp: App {
    @UIApplicationDelegateAdaptor(ParkedAppDelegate.self) private var appDelegate

    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([ParkingSpot.self])
        if let persistent = try? AppDependencies.makeModelContainer() {
            modelContainer = persistent
            ParkedLog.app.info("Using SwiftData ModelContainer only (Core Data stack disabled).")
        } else {
            do {
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(for: schema, configurations: [configuration])
                ParkedLog.app.error("Persistent SwiftData store failed to open; using in-memory store for this session.")
            } catch {
                // REASON: App must always have a container; in-memory creation should not fail for this schema.
                preconditionFailure("SwiftData could not start: \(error.localizedDescription)")
            }
        }
        // REASON: Delegate and BG handlers use the same store as SwiftUI via `container.mainContext`.
        ParkedPersistence.sharedContainer = modelContainer
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
