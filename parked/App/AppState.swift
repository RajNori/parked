//
//  AppState.swift
//  parked
//

import Foundation
import SwiftData
import SwiftUI

/// Top-level `@MainActor` domain coordinator observable by SwiftUI.
@MainActor
@Observable
final class AppState {
    let repository: ParkingRepository
    let locationManager: LocationManager

    init(modelContext: ModelContext) {
        repository = ParkingRepository(modelContext: modelContext)
        locationManager = LocationManager()
        Task { @MainActor in
            await NotificationManager.performLaunchReschedule(repository: repository)
        }
    }
}

// MARK: - Environment

private enum ParkedAppStateKey: EnvironmentKey {
    // REASON: `EnvironmentKey` requires a nonisolated `defaultValue` for Swift 6; `nil` is safe before injection.
    static let defaultValue: AppState? = nil
}

extension EnvironmentValues {
    var parkedAppState: AppState? {
        get { self[ParkedAppStateKey.self] }
        set { self[ParkedAppStateKey.self] = newValue }
    }
}
