//
//  LocationManager.swift
//  parked
//

import CoreLocation
import Foundation
import OSLog

/// Wraps `CLLocationManager` on the main actor for SwiftUI observation.
/// REASON: `CLLocationManagerDelegate` is main-thread-centric; keep the manager on the main actor with `@Observable`.
@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let logger = ParkedLog.location

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var lastLocation: CLLocation?
    private(set) var locationServicesEnabled: Bool

    private var permissionContinuation: CheckedContinuation<Void, Never>?

    override init() {
        // REASON: `@Observable`/`NSObject` require all stored state before `super.init()`.
        authorizationStatus = manager.authorizationStatus
        locationServicesEnabled = true
        lastLocation = nil
        super.init()
        manager.delegate = self
        Task { @MainActor in
            locationServicesEnabled = await Self.readLocationServicesEnabled()
        }
    }

    var isAuthorizedForWhenInUse: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDeniedOrRestricted: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Requests when-in-use authorization; safe to call from onboarding CTA only.
    func requestWhenInUsePermission() async {
        locationServicesEnabled = await Self.readLocationServicesEnabled()
        guard locationServicesEnabled else {
            logger.warning("Location services disabled at system level.")
            return
        }
        let current = manager.authorizationStatus
        guard current == .notDetermined else {
            authorizationStatus = current
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            permissionContinuation = continuation
            // REASON: CLLocation authorization requests are main-thread APIs.
            manager.requestWhenInUseAuthorization()
        }
    }

    func startUpdatingLocation() {
        guard isAuthorizedForWhenInUse else { return }
        // REASON: CLLocationManager start/stop calls are expected on main thread.
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            if let continuation = permissionContinuation {
                permissionContinuation = nil
                continuation.resume()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in
            lastLocation = last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Location update failed: \(error.localizedDescription)")
        }
    }

    nonisolated private static func readLocationServicesEnabled() async -> Bool {
        await Task.detached(priority: .utility) {
            CLLocationManager.locationServicesEnabled()
        }.value
    }
}
