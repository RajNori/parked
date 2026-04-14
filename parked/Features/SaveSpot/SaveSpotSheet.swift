//
//  SaveSpotSheet.swift
//  parked
//

import MapKit
import SwiftUI
import UIKit

struct SaveSpotSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: SaveSpotViewModel
    let onSaved: @MainActor (ParkingSpot) -> Void

    @State private var mapPosition: MapCameraPosition
    @State private var showPhotoPicker = false

    init(viewModel: SaveSpotViewModel, onSaved: @escaping @MainActor (ParkingSpot) -> Void) {
        self.viewModel = viewModel
        self.onSaved = onSaved
        _mapPosition = State(initialValue: .region(MKCoordinateRegion(center: viewModel.draftCoordinate, latitudinalMeters: 180, longitudinalMeters: 180)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView(value: viewModel.progressValue)
                    .padding(.top, 8)

                stepView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .navigationTitle(String(localized: "Save Spot", comment: "Save spot title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cancel", comment: "Cancel save spot")) {
                        if viewModel.requestCancel() { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.canMoveBackward {
                        Button(String(localized: "Back", comment: "Save spot back")) { viewModel.goBack() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar.padding(.horizontal, 20).padding(.top, 8).background(.regularMaterial) }
            .alert(String(localized: "Discard this spot?", comment: "Discard save spot alert title"), isPresented: $viewModel.isShowingCancelConfirmation) {
                Button(String(localized: "Keep editing", comment: "Discard save spot cancel"), role: .cancel) {}
                Button(String(localized: "Discard", comment: "Discard save spot confirm"), role: .destructive) { dismiss() }
            }
            message: {
                Text(String(localized: "You have unsaved changes in this spot draft.", comment: "Discard save spot alert body"))
            }
            .sheet(isPresented: $showPhotoPicker) {
                PHPickerRepresentable { image in
                    Task { @MainActor in
                        showPhotoPicker = false
                        let data = image?.jpegData(compressionQuality: 0.92)
                        await viewModel.applySelectedPhoto(from: data)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch viewModel.stepIndex {
        case 0: confirmLocationStep
        case 1: nicknameStep
        case 2: meterStep
        case 3: photoStep
        default: notesStep
        }
    }

    private var confirmLocationStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Confirm your parking spot", comment: "Save spot step title"))
                .font(.title2.weight(.semibold))
            Text(String(localized: "Pan the map until the pin sits exactly where you parked.", comment: "Save spot map instruction"))
                .font(.body)
                .foregroundStyle(.secondary)
            Map(position: $mapPosition, interactionModes: .all) {
                // REASON: `Annotation` is the iOS 17-safe replacement for deprecated `MapAnnotation`.
                Annotation(String(localized: "Saved location", comment: "Save spot pin title"), coordinate: viewModel.draftCoordinate, anchor: .bottom) { SaveSpotPinView() }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                Task { @MainActor in
                    viewModel.draftCoordinate = context.region.center
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(height: 280)
            Text(GeocodingService.coordinateFallbackString(for: viewModel.draftCoordinate))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var nicknameStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Add a nickname", comment: "Save spot nickname step title"))
                .font(.title2.weight(.semibold))
            Text(String(localized: "Optional: help future-you remember the exact place.", comment: "Save spot nickname body"))
                .font(.body)
                .foregroundStyle(.secondary)
            TextField(String(localized: "Level 2, near elevator", comment: "Save spot nickname placeholder"), text: $viewModel.nickname)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var meterStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Set a meter timer", comment: "Save spot meter step title"))
                .font(.title2.weight(.semibold))
            Toggle(String(localized: "Add a meter reminder", comment: "Save spot meter toggle"), isOn: $viewModel.meterEnabled)
            if viewModel.meterEnabled {
                DatePicker(String(localized: "Expiry time", comment: "Save spot expiry picker label"), selection: $viewModel.meterDate, in: viewModel.minimumMeterDate..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
            }
        }
    }

    private var photoStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Add a photo", comment: "Save spot photo step title"))
                .font(.title2.weight(.semibold))
            Text(String(localized: "Optional: save the floor sign, aisle marker, or nearby landmark.", comment: "Save spot photo body"))
                .font(.body)
                .foregroundStyle(.secondary)
            Button {
                showPhotoPicker = true
            } label: {
                Label(String(localized: "Choose photo", comment: "Save spot choose photo"), systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if viewModel.isLoadingPhoto {
                ProgressView(String(localized: "Preparing photo…", comment: "Save spot photo loading"))
            } else if let data = viewModel.compressedPhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var notesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Add notes", comment: "Save spot notes step title"))
                .font(.title2.weight(.semibold))
            Text(String(localized: "Optional details like floor, aisle, or a landmark.", comment: "Save spot notes body"))
                .font(.body)
                .foregroundStyle(.secondary)
            TextEditor(text: $viewModel.notes)
                .frame(minHeight: 160)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if let inlineErrorMessage = viewModel.inlineErrorMessage {
                Text(inlineErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                Task {
                    if viewModel.stepIndex < 4 {
                        if viewModel.stepIndex == 2, viewModel.meterEnabled {
                            ParkedHaptics.mediumImpact()
                        }
                        viewModel.goNext()
                        return
                    }
                    do {
                        let savedSpot = try await viewModel.save()
                        onSaved(savedSpot)
                        dismiss()
                    } catch {
                        ParkedHaptics.warningNotification()
                        if viewModel.inlineErrorMessage == nil {
                            viewModel.inlineErrorMessage = String(localized: "Could not save this spot right now. Please retry.", comment: "Save spot fallback error")
                        }
                    }
                }
            } label: {
                if viewModel.isSaving {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text(viewModel.stepIndex == 4 ? String(localized: "Save Spot", comment: "Save spot CTA") : String(localized: "Continue", comment: "Save spot continue CTA"))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoadingPhoto || viewModel.isSaving)
        }
        .padding(.bottom, 8)
    }
}

private struct SaveSpotPinView: View {
    var body: some View {
        ZStack {
            Circle().fill(.blue).frame(width: 44, height: 44).shadow(radius: 6, y: 3)
            Image(systemName: "car.fill").font(.title3).foregroundStyle(.white)
        }
    }
}
