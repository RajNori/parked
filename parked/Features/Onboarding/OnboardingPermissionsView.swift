//
//  OnboardingPermissionsView.swift
//  parked
//

import OSLog
import SwiftUI

struct OnboardingPermissionsView: View {
    @Bindable var locationManager: LocationManager
    @AppStorage(AppSettings.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false

    @State private var notificationGranted = false
    @State private var isRunningAllowFlow = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Text(String(localized: "Two quick permissions\nand you're ready.", comment: "Onboarding permissions headline"))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(String(localized: "Parked. works entirely on your device. Your data never leaves your phone.", comment: "Onboarding permissions body"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                permissionRow(
                    icon: "location.fill",
                    tint: .blue,
                    title: String(localized: "Location — When in use", comment: "Permission row title"),
                    desc: String(localized: "To save and find your exact spot", comment: "Permission row subtitle"),
                    granted: locationManager.isAuthorizedForWhenInUse
                )
                permissionRow(
                    icon: "bell.badge.fill",
                    tint: .orange,
                    title: String(localized: "Notifications", comment: "Permission row title"),
                    desc: String(localized: "For meter alerts and spot reminders", comment: "Permission row subtitle"),
                    granted: notificationGranted
                )
            }
            .padding(.horizontal, 4)

            Text(String(localized: "Your location is only used while the app is open. No tracking. No ads.", comment: "Onboarding privacy note"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button {
                    Task { await runAllowFlow() }
                } label: {
                    if isRunningAllowFlow {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    } else {
                        Text(String(localized: "Continue and get started", comment: "Onboarding permissions primary CTA"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isRunningAllowFlow)

                Button(String(localized: "Skip for now", comment: "Onboarding skip permissions")) {
                    hasCompletedOnboarding = true
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }

    private func permissionRow(icon: String, tint: Color, title: String, desc: String, granted: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 36, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func runAllowFlow() async {
        isRunningAllowFlow = true
        defer { isRunningAllowFlow = false }
        await locationManager.requestWhenInUsePermission()
        do {
            _ = try await NotificationManager.requestAuthorization()
        } catch {
            ParkedLog.notifications.error("Notification permission request error: \(error.localizedDescription)")
        }
        notificationGranted = await NotificationManager.authorizationGranted()
        try? await Task.sleep(nanoseconds: 500_000_000)
        ParkedHaptics.successNotification()
        hasCompletedOnboarding = true
    }
}
