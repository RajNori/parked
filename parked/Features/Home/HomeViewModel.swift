//
//  HomeViewModel.swift
//  parked
//

import CoreLocation
import MapKit
import Observation
import OSLog
import SwiftUI
import UIKit

enum ParkHereIntent: Equatable {
    case showReplaceAlert
    case openSaveSheet
}

@MainActor
@Observable
final class HomeViewModel {
    let repository: ParkingRepository
    let locationManager: LocationManager

    var cameraPosition: MapCameraPosition = .automatic
    var saveDraftCoordinate: CLLocationCoordinate2D?
    var inlineErrorMessage: String?
    private(set) var canRetryInlineError = false

    private var retryAction: (@MainActor () -> Void)?
    private var lastFarFromCarNotificationAt: Date?
    private var lastFarFromCarSpotId: UUID?

    init(repository: ParkingRepository, locationManager: LocationManager) {
        self.repository = repository
        self.locationManager = locationManager
    }

    func startLocationUpdatesIfAllowed() {
        if locationManager.isAuthorizedForWhenInUse {
            locationManager.startUpdatingLocation()
        }
    }

    func syncCamera(activeSpot: ParkingSpot?) {
        if let activeSpot {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                cameraPosition = regionPosition(for: activeSpot.coordinate, latitudinalMeters: 240, longitudinalMeters: 240)
            }
            return
        }

        guard locationManager.isDeniedOrRestricted == false else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                cameraPosition = regionPosition(
                    for: currentSaveCoordinate,
                    latitudinalMeters: 800,
                    longitudinalMeters: 800
                )
            }
            return
        }

        if let lastLocation = locationManager.lastLocation {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                cameraPosition = regionPosition(for: lastLocation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            }
        } else if locationManager.isAuthorizedForWhenInUse {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                cameraPosition = .userLocation(fallback: .automatic)
            }
        }
    }

    /// Decides whether the save sheet opens immediately or the replace-confirmation UI should appear first.
    func evaluateParkHereTap(activeSpot: ParkingSpot?) -> ParkHereIntent {
        if activeSpot != nil {
            return .showReplaceAlert
        }
        openSaveFlowUsingBestLocation()
        return .openSaveSheet
    }

    func confirmReplaceAndOpenSaveFlow() {
        openSaveFlowUsingBestLocation()
    }

    func handleSavedSpot(_ spot: ParkingSpot) {
        inlineErrorMessage = nil
        canRetryInlineError = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            cameraPosition = regionPosition(for: spot.coordinate, latitudinalMeters: 240, longitudinalMeters: 240)
        }
        ParkedHaptics.successNotification()
        Task {
            await NotificationManager.cancelAllMeterScheduledNotifications()
            do {
                if AppSettings.notificationsMeterEnabled() {
                    try await NotificationManager.scheduleMeterNotifications(for: spot)
                }
                let address = spot.address ?? GeocodingService.coordinateFallbackString(for: spot.coordinate)
                if AppSettings.notificationsSpotSavedEnabled() {
                    try await NotificationManager.scheduleSpotSavedConfirmation(address: address)
                }
                if AppSettings.notificationsLongParkEnabled() {
                    NotificationManager.submitLongParkBackgroundTask(savedAt: spot.savedAt)
                }
            } catch {
                ParkedLog.notifications.error("Post-save notifications failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func noteSaveError(_ message: String, retry: (@MainActor () -> Void)? = nil) {
        inlineErrorMessage = message
        retryAction = retry
        canRetryInlineError = retry != nil
    }

    func openDirections(for spot: ParkingSpot) {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
        destination.name = spot.name.isEmpty
            ? String(localized: "Parked Car", comment: "Default destination name for active spot")
            : spot.name
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        destination.openInMaps(launchOptions: launchOptions)
    }

    func sharePayload(for spot: ParkingSpot) -> String {
        let coordinateString = String(
            format: String(localized: "%.6f, %.6f", comment: "Shared coordinate string"),
            spot.latitude,
            spot.longitude
        )
        let mapsURL = "https://maps.apple.com/?ll=\(spot.latitude),\(spot.longitude)&q=\(spot.latitude),\(spot.longitude)"
        return String(
            localized: "My parked spot: \(coordinateString)\n\(mapsURL)",
            comment: "Shared active spot payload"
        )
    }

    func openShareSheet(for spot: ParkingSpot) {
        let payload = sharePayload(for: spot)
        let activityController = UIActivityViewController(activityItems: [payload], applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            noteSaveError(String(localized: "Unable to open share sheet right now.", comment: "Share sheet fallback error"))
            return
        }

        var presenter = rootViewController
        while let presentedController = presenter.presentedViewController {
            presenter = presentedController
        }
        presenter.present(activityController, animated: true)
    }

    func updateActiveSpotDetails(_ spot: ParkingSpot, name: String, notes: String) {
        spot.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try repository.save()
        } catch {
            noteSaveError(error.localizedDescription) { [weak self] in
                self?.updateActiveSpotDetails(spot, name: name, notes: notes)
            }
        }
    }

    func removeActiveSpot(_ spot: ParkingSpot) {
        do {
            try repository.delete(spot)
            syncCamera(activeSpot: nil)
            ParkedHaptics.warningNotification()
            Task {
                await NotificationManager.cancelAllMeterScheduledNotifications()
                NotificationManager.cancelLongParkBackgroundTask()
            }
        } catch {
            noteSaveError(error.localizedDescription) { [weak self] in
                self?.removeActiveSpot(spot)
            }
        }
    }

    func clearInlineError() {
        inlineErrorMessage = nil
        retryAction = nil
        canRetryInlineError = false
    }

    func retryInlineErrorAction() {
        guard let retryAction else { return }
        inlineErrorMessage = nil
        canRetryInlineError = false
        self.retryAction = nil
        retryAction()
    }

    var currentSaveCoordinate: CLLocationCoordinate2D {
        if let saveDraftCoordinate {
            return saveDraftCoordinate
        }
        if let lastLocation = locationManager.lastLocation {
            return lastLocation.coordinate
        }
        return CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    }

    var currentSaveHorizontalAccuracyMeters: Double? {
        guard locationManager.isDeniedOrRestricted == false else { return 5000 }
        guard let last = locationManager.lastLocation else { return 5000 }
        let accuracy = last.horizontalAccuracy
        return accuracy > 0 ? accuracy : 5000
    }

    func handleDistanceFromSavedSpotIfNeeded(activeSpot: ParkingSpot?) {
        guard let activeSpot, let location = locationManager.lastLocation else { return }
        let spotLocation = CLLocation(latitude: activeSpot.latitude, longitude: activeSpot.longitude)
        let distance = location.distance(from: spotLocation)
        guard distance >= 500 else { return }
        let now = Date()
        if let lastSpotId = lastFarFromCarSpotId, let lastAt = lastFarFromCarNotificationAt,
           lastSpotId == activeSpot.id, now.timeIntervalSince(lastAt) < 30 * 60 {
            return
        }
        Task {
            await NotificationManager.scheduleFarFromCarNudgeIfAuthorized(for: activeSpot, distanceMeters: distance)
        }
        lastFarFromCarSpotId = activeSpot.id
        lastFarFromCarNotificationAt = now
    }

    private func openSaveFlowUsingBestLocation() {
        saveDraftCoordinate = currentSaveCoordinate
        inlineErrorMessage = nil
    }

    private func regionPosition(for coordinate: CLLocationCoordinate2D, latitudinalMeters: CLLocationDistance, longitudinalMeters: CLLocationDistance) -> MapCameraPosition {
        .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: latitudinalMeters, longitudinalMeters: longitudinalMeters))
    }
}
