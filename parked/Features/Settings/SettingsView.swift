//
//  SettingsView.swift
//  parked
//

import CoreLocation
import MapKit
import SwiftUI
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(\.parkedAppState) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.defaultMeterDurationMinutesKey) private var defaultMeterDurationMinutes = 30
    @AppStorage(AppSettings.mapStyleKey) private var mapStyleRawValue = MapStyleOption.standard.rawValue
    @AppStorage(AppSettings.notificationsMeterEnabledKey) private var notificationsMeterEnabled = true
    @AppStorage(AppSettings.notificationsSpotSavedEnabledKey) private var notificationsSpotSavedEnabled = true
    @AppStorage(AppSettings.notificationsLongParkEnabledKey) private var notificationsLongParkEnabled = true

    @State private var notificationSettings: UNNotificationSettings?
    @ScaledMetric(relativeTo: .body) private var previewCardWidth: CGFloat = 140
    @ScaledMetric(relativeTo: .body) private var previewCardHeight: CGFloat = 100

    private let durationOptions = [15, 30, 45, 60, 90, 120]
    private var selectedMapStyle: MapStyleOption {
        get { MapStyleOption(rawValue: mapStyleRawValue) ?? .standard }
        nonmutating set { mapStyleRawValue = newValue.rawValue }
    }

    private var locationStatusText: String {
        guard let appState else { return String(localized: "Unavailable", comment: "Unknown permission status") }
        return Self.locationText(for: appState.locationManager.authorizationStatus)
    }

    private var notificationStatusText: String {
        guard let settings = notificationSettings else {
            return String(localized: "Checking…", comment: "Checking notification status")
        }
        switch settings.authorizationStatus {
        case .authorized:
            return String(localized: "Allowed", comment: "Notification status allowed")
        case .provisional:
            return String(localized: "Provisional", comment: "Notification status provisional")
        case .denied:
            return String(localized: "Denied", comment: "Notification status denied")
        case .notDetermined:
            return String(localized: "Not determined", comment: "Notification status not determined")
        case .ephemeral:
            return String(localized: "Ephemeral", comment: "Notification status ephemeral")
        @unknown default:
            return String(localized: "Unknown", comment: "Notification status unknown")
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return String(localized: "Version \(version) (\(build))", comment: "App version and build")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Map style", comment: "Settings section title")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(MapStyleOption.allCases) { style in
                                mapStyleCard(style)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(String(localized: "Parking", comment: "Settings section title")) {
                    Picker(String(localized: "Default meter duration", comment: "Default meter picker title"), selection: $defaultMeterDurationMinutes) {
                        ForEach(durationOptions, id: \.self) { minutes in
                            Text(
                                String(
                                    localized: "\(minutes) minutes",
                                    comment: "Default meter duration option in minutes"
                                )
                            )
                            .tag(minutes)
                        }
                    }
                }

                Section(String(localized: "Notifications", comment: "Settings section title")) {
                    Toggle(String(localized: "Meter reminders", comment: "Settings notifications meter toggle"), isOn: $notificationsMeterEnabled)
                    Toggle(String(localized: "Spot saved confirmation", comment: "Settings notifications spot saved toggle"), isOn: $notificationsSpotSavedEnabled)
                    Toggle(String(localized: "Long-park nudge", comment: "Settings notifications long park toggle"), isOn: $notificationsLongParkEnabled)
                }

                Section(String(localized: "Permissions", comment: "Settings section title")) {
                    permissionRow(
                        title: String(localized: "Location", comment: "Settings location permission row"),
                        status: locationStatusText
                    )
                    permissionRow(
                        title: String(localized: "Notifications", comment: "Settings notifications permission row"),
                        status: notificationStatusText
                    )
                    Button(String(localized: "Open iOS Settings", comment: "Open iOS Settings button")) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }

                Section(String(localized: "About", comment: "Settings section title")) {
                    Text(appVersionText)
                }
            }
            .navigationTitle(String(localized: "Settings", comment: "Settings navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandMark()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done", comment: "Settings done button")) {
                        dismiss()
                    }
                }
            }
            .task {
                if defaultMeterDurationMinutes <= 0 {
                    defaultMeterDurationMinutes = 30
                }
                await refreshNotificationStatus()
            }
            .onChange(of: scenePhase) { _, newValue in
                guard newValue == .active else { return }
                Task { await refreshNotificationStatus() }
            }
        }
    }

    private func mapStyleCard(_ style: MapStyleOption) -> some View {
        let isSelected = selectedMapStyle == style
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedMapStyle = style
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Map(
                        initialPosition: .region(
                            MKCoordinateRegion(
                                center: MapStylePreview.scenicCoordinate,
                                latitudinalMeters: 1200,
                                longitudinalMeters: 1200
                            )
                        ),
                        interactionModes: []
                    ) {
                        Annotation(
                            String(localized: "Sydney", comment: "Map style preview annotation"),
                            coordinate: MapStylePreview.scenicCoordinate
                        ) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .mapStyle(style.mapStyle)
                    .frame(width: previewCardWidth, height: previewCardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .blue)
                            .padding(6)
                    }
                }
                Text(style.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
    }

    private func permissionRow(title: String, status: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(status)
                .foregroundStyle(.secondary)
        }
    }

    private func refreshNotificationStatus() async {
        notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
    }

    private static func locationText(for status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways:
            return String(localized: "Always", comment: "Location status always")
        case .authorizedWhenInUse:
            return String(localized: "When in use", comment: "Location status when in use")
        case .denied:
            return String(localized: "Denied", comment: "Location status denied")
        case .notDetermined:
            return String(localized: "Not determined", comment: "Location status not determined")
        case .restricted:
            return String(localized: "Restricted", comment: "Location status restricted")
        @unknown default:
            return String(localized: "Unknown", comment: "Location status unknown")
        }
    }
}
