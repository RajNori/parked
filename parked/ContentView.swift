//
//  ContentView.swift
//  parked
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettings.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false

    @State private var appState: AppState?
    @State private var meterExpiredBanner: MeterExpiredBannerPayload?

    private var shouldPresentOnboarding: Bool {
        !hasCompletedOnboarding && appState != nil
    }

    var body: some View {
        ZStack {
            if let appState {
                HomeView()
                    .environment(\.parkedAppState, appState)
            } else {
                ProgressView(String(localized: "Loading…", comment: "Initial app load"))
            }
        }
        .animation(.default, value: appState != nil)
        .overlay(alignment: .top) {
            if let payload = meterExpiredBanner {
                MeterExpiredBannerView(
                    payload: payload,
                    onDismiss: {
                        meterExpiredBanner = nil
                    },
                    onGetDirections: {
                        MeterExpiredBannerView.openWalkingDirections(payload: payload)
                        meterExpiredBanner = nil
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: payload.spotId) {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if meterExpiredBanner?.spotId == payload.spotId {
                        meterExpiredBanner = nil
                    }
                }
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: meterExpiredBanner?.spotId)
        .onReceive(NotificationCenter.default.publisher(for: .parkedMeterExpired)) { note in
            guard let info = note.userInfo,
                  let spotId = info[ParkedMeterExpiredUserInfoKey.spotId] as? String,
                  let lat = double(from: info, key: ParkedMeterExpiredUserInfoKey.latitude),
                  let lng = double(from: info, key: ParkedMeterExpiredUserInfoKey.longitude),
                  let address = info[ParkedMeterExpiredUserInfoKey.address] as? String else { return }
            Task { @MainActor in
                meterExpiredBanner = MeterExpiredBannerPayload(
                    spotId: spotId,
                    latitude: lat,
                    longitude: lng,
                    address: address
                )
            }
        }
        .task {
            if appState == nil {
                appState = AppState(modelContext: modelContext)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { shouldPresentOnboarding }, set: { _ in })) {
            if let appState {
                OnboardingView(locationManager: appState.locationManager)
                    .environment(\.parkedAppState, appState)
                    .interactiveDismissDisabled(true)
            }
        }
    }

    private func double(from userInfo: [AnyHashable: Any], key: String) -> Double? {
        if let d = userInfo[key] as? Double {
            return d
        }
        if let n = userInfo[key] as? NSNumber {
            return n.doubleValue
        }
        return nil
    }
}

private struct ContentViewPreviewHost: View {
    var body: some View {
        Group {
            if let container = try? AppDependencies.makePreviewModelContainer() {
                ContentView()
                    .modelContainer(container)
                    .onAppear {
                        ParkedPersistence.sharedContainer = container
                    }
            } else {
                Text(String(localized: "Preview unavailable", comment: "SwiftUI preview failure"))
            }
        }
    }
}

#Preview("ContentView") {
    ContentViewPreviewHost()
}
