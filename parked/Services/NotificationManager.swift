//
//  NotificationManager.swift
//  parked
//

import BackgroundTasks
import Foundation
import OSLog
import SwiftData
import UserNotifications

/// Local notification registration, scheduling, and permission requests.
enum NotificationManager {
    private static let logger = ParkedLog.notifications

    static let categoryMeterWarning = "METER_WARNING"
    static let categoryMeterExpired = "METER_EXPIRED"
    static let categorySpotSaved = "SPOT_SAVED"

    static let actionDismissMeter = "DISMISS_METER"
    static let actionExtendMeter = "EXTEND_METER"

    static let longParkTaskIdentifier = "com.parked.app.longpark"

    private static let userInfoSpotId = "spotId"
    private static let userInfoLatitude = "latitude"
    private static let userInfoLongitude = "longitude"
    private static let userInfoAddress = "address"

    enum NotificationPermissionError: LocalizedError {
        case denied

        var errorDescription: String? {
            switch self {
            case .denied:
                String(localized: "Notifications are off for Parked.", comment: "Error when notifications denied")
            }
        }
    }

    // MARK: - Categories

    /// Registers categories used by meter warnings, expiry, and spot saved confirmation.
    static func registerCategories() {
        let dismiss = UNNotificationAction(
            identifier: actionDismissMeter,
            title: String(localized: "I'm on my way", comment: "Meter notification action"),
            options: []
        )
        let extend = UNNotificationAction(
            identifier: actionExtendMeter,
            title: String(localized: "Add 30 min", comment: "Meter notification action"),
            options: []
        )
        let meterWarning = UNNotificationCategory(
            identifier: categoryMeterWarning,
            actions: [dismiss, extend],
            intentIdentifiers: [],
            options: []
        )
        let meterExpired = UNNotificationCategory(
            identifier: categoryMeterExpired,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let spotSaved = UNNotificationCategory(
            identifier: categorySpotSaved,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([meterWarning, meterExpired, spotSaved])
    }

    // MARK: - Authorization

    static func requestAuthorization() async throws -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            logger.error("Notification authorization request failed: \(error.localizedDescription)")
            throw error
        }
    }

    static func authorizationGranted() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Identifiers

    private static func meterWarningIdentifier(spotId: UUID, minutesBeforeExpiry: Int) -> String {
        "parked.meter.\(spotId.uuidString).\(minutesBeforeExpiry)"
    }

    private static func meterExpiryIdentifier(spotId: UUID) -> String {
        "parked.expiry.\(spotId.uuidString)"
    }

    // MARK: - Cancel

    static func cancelMeterNotifications(spotId: UUID) async {
        let ids = [
            meterWarningIdentifier(spotId: spotId, minutesBeforeExpiry: 15),
            meterWarningIdentifier(spotId: spotId, minutesBeforeExpiry: 10),
            meterWarningIdentifier(spotId: spotId, minutesBeforeExpiry: 5),
            meterExpiryIdentifier(spotId: spotId),
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Clears all pending meter-related requests (any spot). Used when saving a new active spot.
    static func cancelAllMeterScheduledNotifications() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { id in
            id.hasPrefix("parked.meter.") || id.hasPrefix("parked.expiry.")
        }
        guard ids.isEmpty == false else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Schedule meter

    /// Staggered warnings at 15 / 10 / 5 minutes before expiry, plus an expiry marker for foreground handling.
    static func scheduleMeterNotifications(for spot: ParkingSpot) async throws {
        guard AppSettings.notificationsMeterEnabled() else { return }
        await cancelMeterNotifications(spotId: spot.id)
        guard let expiresAt = spot.expiresAt else { return }
        let now = Date()
        guard expiresAt > now else {
            logger.info("Meter expiry already passed; skipping meter schedule.")
            return
        }

        let center = UNUserNotificationCenter.current()
        let address = spot.address ?? GeocodingService.coordinateFallbackString(for: spot.coordinate)
        let baseUserInfo: [AnyHashable: Any] = [
            userInfoSpotId: spot.id.uuidString,
            userInfoLatitude: spot.latitude,
            userInfoLongitude: spot.longitude,
            userInfoAddress: address,
        ]

        for minutesBefore in [15, 10, 5] {
            let fireDate = expiresAt.addingTimeInterval(-Double(minutesBefore * 60))
            guard fireDate > now.addingTimeInterval(1) else { continue }
            let interval = fireDate.timeIntervalSince(now)
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Meter reminder", comment: "Meter warning notification title")
            content.body = String(
                localized: "Your meter expires in \(minutesBefore) minutes.",
                comment: "Meter warning notification body"
            )
            content.categoryIdentifier = categoryMeterWarning
            content.sound = .default
            content.userInfo = baseUserInfo
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: meterWarningIdentifier(spotId: spot.id, minutesBeforeExpiry: minutesBefore),
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }

        let expiryInterval = expiresAt.timeIntervalSince(now)
        guard expiryInterval > 1 else { return }
        let expiryContent = UNMutableNotificationContent()
        expiryContent.title = String(localized: "Meter expired", comment: "Meter expired notification title")
        expiryContent.body = address
        expiryContent.categoryIdentifier = categoryMeterExpired
        expiryContent.sound = .default
        expiryContent.userInfo = baseUserInfo
        let expiryTrigger = UNTimeIntervalNotificationTrigger(timeInterval: expiryInterval, repeats: false)
        let expiryRequest = UNNotificationRequest(
            identifier: meterExpiryIdentifier(spotId: spot.id),
            content: expiryContent,
            trigger: expiryTrigger
        )
        try await center.add(expiryRequest)
    }

    /// After extending meter time on disk, refresh pending meter notifications for that spot.
    static func rescheduleMeterAfterExtend(spot: ParkingSpot) async throws {
        try await scheduleMeterNotifications(for: spot)
    }

    // MARK: - Spot saved

    static func scheduleSpotSavedConfirmation(address: String) async throws {
        guard AppSettings.notificationsSpotSavedEnabled() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Spot saved", comment: "Spot saved notification title")
        content.body = address
        content.categoryIdentifier = categorySpotSaved
        content.sound = nil
        content.interruptionLevel = .passive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let id = "parked.saved.\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Long park (BG + local)

    static func submitLongParkBackgroundTask(savedAt: Date) {
        submitLongParkBackgroundTask(savedAt: savedAt, forceImmediate: false)
    }

    static func submitLongParkBackgroundTask(savedAt: Date, forceImmediate: Bool) {
        guard AppSettings.notificationsLongParkEnabled() else { return }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: longParkTaskIdentifier)
        let request = BGProcessingTaskRequest(identifier: longParkTaskIdentifier)
        request.earliestBeginDate = forceImmediate ? Date() : savedAt.addingTimeInterval(8 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Long park BG submit failed: \(error.localizedDescription)")
        }
    }

    static func cancelLongParkBackgroundTask() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: longParkTaskIdentifier)
    }

    static func scheduleLongParkNudge(for spot: ParkingSpot) async throws {
        guard AppSettings.notificationsLongParkEnabled() else { return }
        let address = spot.address ?? GeocodingService.coordinateFallbackString(for: spot.coordinate)
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Still parked?", comment: "Long park notification title")
        content.body = String(localized: "Still parked at \(address)?", comment: "Long park notification body")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "parked.longpark.\(spot.id.uuidString).\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    static func scheduleFarFromCarNudgeIfAuthorized(for spot: ParkingSpot, distanceMeters: Double) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let address = spot.address ?? GeocodingService.coordinateFallbackString(for: spot.coordinate)
        let content = UNMutableNotificationContent()
        content.title = String(localized: "You seem far from your parked car", comment: "Far from car notification title")
        content.body = String(localized: "Your saved spot is near \(address).", comment: "Far from car notification body")
        content.sound = .default
        content.userInfo = [userInfoSpotId: spot.id.uuidString, "distanceMeters": distanceMeters]
        let request = UNNotificationRequest(
            identifier: "parked.farcar.\(spot.id.uuidString).\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Far from car notification failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    static func performLaunchReschedule(repository: ParkingRepository) async {
        do {
            guard let spot = try repository.activeSpot(), spot.isActive else { return }
            if AppSettings.notificationsMeterEnabled(),
               let expires = spot.expiresAt,
               expires > Date() {
                try await scheduleMeterNotifications(for: spot)
            }
            if AppSettings.notificationsLongParkEnabled() {
                let activeFor = Date().timeIntervalSince(spot.savedAt)
                let forceImmediate = activeFor >= 7 * 60 * 60
                submitLongParkBackgroundTask(savedAt: spot.savedAt, forceImmediate: forceImmediate)
            }
        } catch {
            logger.error("Launch reschedule failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Relaunch

    /// Re-schedules meter notifications if an active spot with a future meter exists (e.g. after reboot).
    @MainActor
    static func rescheduleActiveSpotNotifications(repository: ParkingRepository) async {
        await performLaunchReschedule(repository: repository)
    }

    // MARK: - Action handlers (MainActor + mainContext)

    @MainActor
    static func handleDismissMeter(spotId: UUID) async {
        await cancelMeterNotifications(spotId: spotId)
    }

    @MainActor
    static func handleExtendMeter(spotId: UUID) async {
        guard let container = ParkedPersistence.sharedContainer else {
            logger.error("Extend meter: no shared ModelContainer.")
            return
        }
        let repository = ParkingRepository(modelContext: container.mainContext)
        do {
            guard let spot = try repository.spot(id: spotId), spot.isActive else { return }
            guard let current = spot.expiresAt else { return }
            spot.expiresAt = current.addingTimeInterval(30 * 60)
            try repository.save()
            try await rescheduleMeterAfterExtend(spot: spot)
        } catch {
            logger.error("Extend meter failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    static func handleLongParkBackgroundCheck() async {
        guard let container = ParkedPersistence.sharedContainer else {
            logger.error("Long park BG: no shared ModelContainer.")
            return
        }
        let repository = ParkingRepository(modelContext: container.mainContext)
        do {
            guard let spot = try repository.activeSpot(), spot.isActive else { return }
            let deadline = spot.savedAt.addingTimeInterval(8 * 60 * 60)
            guard Date() >= deadline else { return }
            try await scheduleLongParkNudge(for: spot)
        } catch {
            logger.error("Long park BG check failed: \(error.localizedDescription)")
        }
    }
}
