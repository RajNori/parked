//
//  HomeView.swift
//  parked
//

import CoreLocation
import MapKit
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

enum HomeSheet: Identifiable {
    case saveSpot
    case history
    case settings

    var id: Self { self }
}

struct HomeView: View {
    @Environment(\.parkedAppState) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.mapStyleKey) private var mapStyleRawValue = MapStyleOption.standard.rawValue
    @AppStorage(AppSettings.notificationDeniedNudgeDismissedKey) private var notificationDeniedNudgeDismissed = false
    @Query(filter: #Predicate<ParkingSpot> { $0.isActive == true }, sort: [SortDescriptor(\ParkingSpot.savedAt, order: .reverse)])
    private var activeSpots: [ParkingSpot]

    @State private var viewModel: HomeViewModel?
    @State private var pinScale: CGFloat = 1
    @State private var activeSheet: HomeSheet?
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var isShowingRemoveConfirmation = false
    @State private var showReplaceAlert = false
    @State private var notificationSettings: UNNotificationSettings?

    private var activeSpot: ParkingSpot? { activeSpots.first }
    private var selectedMapStyle: MapStyleOption {
        MapStyleOption(rawValue: mapStyleRawValue) ?? .standard
    }
    private var shouldShowNotificationDeniedNudge: Bool {
        guard activeSpot != nil else { return false }
        guard notificationDeniedNudgeDismissed == false else { return false }
        guard let notificationSettings else { return false }
        return notificationSettings.authorizationStatus == .denied
    }

    var body: some View {
        Group {
            if let appState {
                if let viewModel {
                    content(appState: appState, viewModel: viewModel)
                } else {
                    ProgressView(String(localized: "Loading map…", comment: "Home loading"))
                        .task {
                            let created = HomeViewModel(
                                repository: appState.repository,
                                locationManager: appState.locationManager
                            )
                            await MainActor.run {
                                viewModel = created
                                mapCameraPosition = created.cameraPosition
                            }
                        }
                }
            } else {
                ProgressView(String(localized: "Loading map…", comment: "Home loading"))
            }
        }
    }

    private func content(appState: AppState, viewModel: HomeViewModel) -> some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                mapLayer(appState: appState, viewModel: viewModel)
                    .ignoresSafeArea()
                if appState.locationManager.isDeniedOrRestricted {
                    locationDeniedOverlay(for: appState.locationManager.authorizationStatus)
                        .padding(24)
                }
                fab(viewModel: viewModel).padding(.trailing, 20).padding(.bottom, 28)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .saveSpot:
                    SaveSpotSheet(
                        viewModel: SaveSpotViewModel(
                            repository: appState.repository,
                            initialCoordinate: viewModel.currentSaveCoordinate,
                            initialHorizontalAccuracyMeters: viewModel.currentSaveHorizontalAccuracyMeters,
                            defaultMeterDurationMinutes: AppSettings.defaultMeterDurationMinutes()
                        ),
                        onSaved: { savedSpot in
                            Task { @MainActor in
                                viewModel.handleSavedSpot(savedSpot)
                            }
                        }
                    )
                case .history:
                    NavigationStack { SpotHistoryView() }
                case .settings:
                    SettingsView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandMark()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            Task { @MainActor in
                                viewModel.syncCamera(activeSpot: activeSpot)
                                mapCameraPosition = viewModel.cameraPosition
                            }
                        } label: {
                            Image(systemName: "location.circle")
                        }
                        .accessibilityLabel(String(localized: "Recenter map", comment: "Home toolbar recenter accessibility label"))

                        Button {
                            Task { @MainActor in
                                activeSheet = .history
                            }
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .accessibilityLabel(String(localized: "Open history", comment: "Home history accessibility label"))

                        Button {
                            Task { @MainActor in
                                activeSheet = .settings
                            }
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(String(localized: "Open settings", comment: "Home settings accessibility label"))
                    }
                }
            }
            .alert(
                String(localized: "Replace current spot?", comment: "Replace active spot alert title"),
                isPresented: $showReplaceAlert
            ) {
                Button(String(localized: "Keep current spot", comment: "Replace spot cancel"), role: .cancel) {
                    Task { @MainActor in
                        showReplaceAlert = false
                    }
                }
                Button(String(localized: "Replace", comment: "Replace spot confirm"), role: .destructive) {
                    Task { @MainActor in
                        ParkedHaptics.warningNotification()
                        viewModel.confirmReplaceAndOpenSaveFlow()
                        showReplaceAlert = false
                        activeSheet = .saveSpot
                    }
                }
            } message: {
                Text(String(localized: "Saving a new spot will replace your current active spot.", comment: "Replace active spot alert body"))
            }
            .task {
                Task { @MainActor in
                    viewModel.startLocationUpdatesIfAllowed()
                    viewModel.syncCamera(activeSpot: activeSpot)
                    mapCameraPosition = viewModel.cameraPosition
                }
                await refreshNotificationPermissionStatus()
            }
            .onChange(of: activeSpot?.id) { _, _ in
                Task { @MainActor in
                    animatePinAppearance()
                    viewModel.syncCamera(activeSpot: activeSpot)
                    mapCameraPosition = viewModel.cameraPosition
                }
            }
            .onChange(of: appState.locationManager.lastLocation?.coordinate.latitude) { _, _ in
                Task { @MainActor in
                    if activeSpot == nil {
                        viewModel.syncCamera(activeSpot: nil)
                        mapCameraPosition = viewModel.cameraPosition
                    }
                    viewModel.handleDistanceFromSavedSpotIfNeeded(activeSpot: activeSpot)
                }
            }
            .onChange(of: scenePhase) { _, newValue in
                guard newValue == .active else { return }
                Task {
                    await refreshNotificationPermissionStatus()
                }
            }
            .onChange(of: viewModel.cameraPosition) { _, newValue in
                Task { @MainActor in
                    mapCameraPosition = newValue
                }
            }
            .safeAreaInset(edge: .bottom) {
                homeBottomCard(viewModel: viewModel)
            }
            .alert(
                String(localized: "Remove saved spot?", comment: "Remove spot confirmation title"),
                isPresented: $isShowingRemoveConfirmation
            ) {
                Button(String(localized: "Cancel", comment: "Remove spot cancel"), role: .cancel) {}
                Button(String(localized: "Remove", comment: "Remove spot confirm"), role: .destructive) {
                    if let activeSpot {
                        Task { @MainActor in
                            viewModel.removeActiveSpot(activeSpot)
                            mapCameraPosition = viewModel.cameraPosition
                        }
                    }
                }
            } message: {
                Text(String(localized: "This removes the current active parking spot.", comment: "Remove spot confirmation message"))
            }
        }
    }

    private func mapPositionBinding(viewModel: HomeViewModel) -> Binding<MapCameraPosition> {
        // REASON: Defer `Map` position writes off the synchronous Binding setter path to avoid mutating `@State` during view updates.
        Binding(
            get: { mapCameraPosition },
            set: { newValue in
                Task { @MainActor in
                    viewModel.cameraPosition = newValue
                    mapCameraPosition = newValue
                }
            }
        )
    }

    private func mapLayer(appState: AppState, viewModel: HomeViewModel) -> some View {
        Map(position: mapPositionBinding(viewModel: viewModel), interactionModes: .all) {
            UserAnnotation()
            if let activeSpot {
                Annotation(
                    activeSpot.name.isEmpty
                        ? String(localized: "Saved spot", comment: "Fallback active spot annotation title")
                        : activeSpot.name,
                    coordinate: activeSpot.coordinate,
                    anchor: .bottom
                ) {
                    activeSpotAnnotation
                }
            }
        }
        .mapStyle(selectedMapStyle.mapStyle)
        .mapControls {
            MapCompass()
            MapUserLocationButton()
        }
        .overlay(alignment: .bottom) {
            if let inlineError = viewModel.inlineErrorMessage {
                VStack(spacing: 6) {
                    Text(inlineError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if viewModel.canRetryInlineError {
                        Button(String(localized: "Retry", comment: "Home inline error retry button")) {
                            Task { @MainActor in
                                viewModel.retryInlineErrorAction()
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .onTapGesture {
                    Task { @MainActor in
                        viewModel.clearInlineError()
                    }
                }
            } else if activeSpot == nil, appState.locationManager.isDeniedOrRestricted == false {
                Text(String(localized: "No spot saved", comment: "Home empty state text"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 12)
            }
        }
    }

    private var activeSpotAnnotation: some View {
        ZStack {
            Circle().fill(.blue).frame(width: 44, height: 44).shadow(radius: 6, y: 3)
            Image(systemName: "car.fill").font(.title3).foregroundStyle(.white)
        }
        .scaleEffect(pinScale)
        .contentShape(Circle())
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Your parked car", comment: "Active map annotation accessibility label"))
        .accessibilityHint(String(localized: "Double tap to see spot details", comment: "Active map annotation accessibility hint"))
    }

    private func fab(viewModel: HomeViewModel) -> some View {
        Button {
            Task { @MainActor in
                switch viewModel.evaluateParkHereTap(activeSpot: activeSpot) {
                case .showReplaceAlert:
                    showReplaceAlert = true
                case .openSaveSheet:
                    activeSheet = .saveSpot
                }
            }
        } label: {
            Label(String(localized: "Park Here", comment: "Park here FAB label"), systemImage: "plus.circle.fill")
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.blue, in: Capsule())
                .foregroundStyle(.white)
                .shadow(radius: 8, y: 4)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(String(localized: "Park here", comment: "Park Here FAB accessibility label"))
        .accessibilityHint(String(localized: "Saves your current location as a parking spot", comment: "Park Here FAB accessibility hint"))
    }

    private func homeBottomCard(viewModel: HomeViewModel) -> some View {
        Group {
            if let activeSpot {
                VStack(spacing: 10) {
                    ActiveSpotCard(
                        spot: activeSpot,
                        onDirections: {
                            Task { @MainActor in
                                ParkedHaptics.lightImpact()
                                viewModel.openDirections(for: activeSpot)
                            }
                        },
                        onShare: {
                            Task { @MainActor in
                                viewModel.openShareSheet(for: activeSpot)
                            }
                        },
                        onRemove: {
                            Task { @MainActor in
                                isShowingRemoveConfirmation = true
                            }
                        },
                        onSaveEdits: { name, notes in
                            Task { @MainActor in
                                viewModel.updateActiveSpotDetails(activeSpot, name: name, notes: notes)
                            }
                        }
                    )
                    if shouldShowNotificationDeniedNudge {
                        notificationDeniedNudgeCard
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "No spot saved", comment: "Home empty card title"))
                        .font(.title2.weight(.semibold))
                    Text(String(localized: "Tap Park Here when you arrive. We'll save your spot and center the map for the walk back.", comment: "Home empty card body"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
    }

    private func locationDeniedOverlay(for status: CLAuthorizationStatus) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)
            Text(
                status == .restricted
                    ? String(localized: "Location access is restricted", comment: "Location restricted title")
                    : String(localized: "Location access is off", comment: "Location denied title")
            )
                .font(.title3.weight(.semibold))
            Text(
                status == .restricted
                    ? String(localized: "Your device restrictions prevent location updates. Parked. can still show your saved spot.", comment: "Location restricted body")
                    : String(localized: "Enable location in Settings so Parked. can save and guide you back to your car.", comment: "Location denied body")
            )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if status != .restricted {
                Button(String(localized: "Open Settings", comment: "Open settings CTA")) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var notificationDeniedNudgeCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Notifications are off", comment: "Notification denied nudge title"))
                    .font(.headline)
                Text(String(localized: "Turn on notifications to get meter reminders and long-park nudges.", comment: "Notification denied nudge body"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button(String(localized: "Open Settings", comment: "Notification nudge open settings")) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(String(localized: "Dismiss", comment: "Notification nudge dismiss")) {
                        notificationDeniedNudgeDismissed = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func refreshNotificationPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notificationSettings = settings
            if settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional ||
                settings.authorizationStatus == .ephemeral {
                notificationDeniedNudgeDismissed = false
            }
        }
    }

    private func animatePinAppearance() {
        Task { @MainActor in
            pinScale = 0.6
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                pinScale = 1.1
            }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                pinScale = 1.0
            }
        }
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
