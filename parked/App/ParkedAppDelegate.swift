//
//  ParkedAppDelegate.swift
//  parked
//

import BackgroundTasks
import OSLog
import UIKit
import UserNotifications

/// Hosts `UNUserNotificationCenter` delegate callbacks outside SwiftUI views.
final class ParkedAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.registerCategories()
        // REASON: `register` must complete before launch returns; keep call in `application(_:didFinishLaunchingWithOptions:)` only (not SwiftUI `.task`).
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: NotificationManager.longParkTaskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Self.runLongParkProcessingTask(processingTask)
        }
        if !registered {
            ParkedLog.app.error("BGTaskScheduler did not register long-park task (identifier missing from BGTaskSchedulerPermittedIdentifiers in Info.plist).")
        }
        return true
    }

    private static func runLongParkProcessingTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        Task { @MainActor in
            await NotificationManager.handleLongParkBackgroundCheck()
            task.setTaskCompleted(success: true)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let category = notification.request.content.categoryIdentifier
        if category == NotificationManager.categoryMeterExpired {
            NotificationCenter.default.post(
                name: .parkedMeterExpired,
                object: nil,
                userInfo: notification.request.content.userInfo
            )
            completionHandler([])
            return
        }
        if category == NotificationManager.categoryMeterWarning {
            completionHandler([.banner, .list])
            return
        }
        if category == NotificationManager.categorySpotSaved {
            completionHandler([.banner, .list])
            return
        }
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        guard action == NotificationManager.actionDismissMeter || action == NotificationManager.actionExtendMeter else {
            completionHandler()
            return
        }
        guard let spotIdString = response.notification.request.content.userInfo["spotId"] as? String,
              let spotId = UUID(uuidString: spotIdString) else {
            completionHandler()
            return
        }

        if action == NotificationManager.actionDismissMeter {
            Task { @MainActor in
                await NotificationManager.handleDismissMeter(spotId: spotId)
                completionHandler()
            }
        } else {
            Task { @MainActor in
                await NotificationManager.handleExtendMeter(spotId: spotId)
                completionHandler()
            }
        }
    }
}
