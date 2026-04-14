//
//  AppSettings.swift
//  parked
//

import Foundation

enum AppSettings {
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    static let defaultMeterDurationMinutesKey = "defaultMeterDurationMinutes"
    static let mapStyleKey = "mapStyle"
    static let notificationsMeterEnabledKey = "notifications.meter.enabled"
    static let notificationsSpotSavedEnabledKey = "notifications.spotSaved.enabled"
    static let notificationsLongParkEnabledKey = "notifications.longPark.enabled"
    static let notificationDeniedNudgeDismissedKey = "notifications.deniedNudge.dismissed"

    static func defaultMeterDurationMinutes(from defaults: UserDefaults = .standard) -> Int {
        let stored = defaults.integer(forKey: defaultMeterDurationMinutesKey)
        return stored > 0 ? stored : 30
    }

    static func notificationsMeterEnabled(from defaults: UserDefaults = .standard) -> Bool {
        bool(forKey: notificationsMeterEnabledKey, default: true, from: defaults)
    }

    static func notificationsSpotSavedEnabled(from defaults: UserDefaults = .standard) -> Bool {
        bool(forKey: notificationsSpotSavedEnabledKey, default: true, from: defaults)
    }

    static func notificationsLongParkEnabled(from defaults: UserDefaults = .standard) -> Bool {
        bool(forKey: notificationsLongParkEnabledKey, default: true, from: defaults)
    }

    static func notificationDeniedNudgeDismissed(from defaults: UserDefaults = .standard) -> Bool {
        bool(forKey: notificationDeniedNudgeDismissedKey, default: false, from: defaults)
    }

    private static func bool(forKey key: String, default defaultValue: Bool, from defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.bool(forKey: key)
    }
}
