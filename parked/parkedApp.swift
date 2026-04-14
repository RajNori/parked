//
//  parkedApp.swift
//  parked
//
//  Created by Raj on 14/4/2026.
//

import SwiftUI
import CoreData

@main
struct parkedApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
