//
//  SaveSpotViewModel.swift
//  parked
//

import CoreLocation
import Foundation
import OSLog

@MainActor
@Observable
final class SaveSpotViewModel {
    let repository: ParkingRepository
    let initialCoordinate: CLLocationCoordinate2D
    let initialHorizontalAccuracyMeters: Double?

    var stepIndex = 0
    var draftCoordinate: CLLocationCoordinate2D
    var nickname = ""
    var meterEnabled = false
    var meterDate = Date().addingTimeInterval(30 * 60)
    var notes = ""
    var compressedPhotoData: Data?
    var isLoadingPhoto = false
    var isSaving = false
    var inlineErrorMessage: String?
    var isShowingCancelConfirmation = false

    private let logger = ParkedLog.saveSpot

    init(
        repository: ParkingRepository,
        initialCoordinate: CLLocationCoordinate2D,
        initialHorizontalAccuracyMeters: Double? = nil,
        defaultMeterDurationMinutes: Int = 30
    ) {
        self.repository = repository
        self.initialCoordinate = initialCoordinate
        self.initialHorizontalAccuracyMeters = initialHorizontalAccuracyMeters
        draftCoordinate = initialCoordinate
        let minutes = max(defaultMeterDurationMinutes, 5)
        meterDate = Date().addingTimeInterval(Double(minutes * 60))
    }

    var progressValue: Double {
        Double(stepIndex + 1) / 5.0
    }

    var minimumMeterDate: Date {
        Date().addingTimeInterval(5 * 60)
    }

    var canMoveBackward: Bool {
        stepIndex > 0
    }

    var hasEnteredData: Bool {
        nickname.isEmpty == false || meterEnabled || notes.isEmpty == false || compressedPhotoData != nil || stepIndex > 0 || draftCoordinate.latitude != initialCoordinate.latitude || draftCoordinate.longitude != initialCoordinate.longitude
    }

    func goNext() {
        inlineErrorMessage = nil
        stepIndex = min(4, stepIndex + 1)
    }

    func goBack() {
        inlineErrorMessage = nil
        stepIndex = max(0, stepIndex - 1)
    }

    func requestCancel() -> Bool {
        if hasEnteredData {
            isShowingCancelConfirmation = true
            return false
        }
        return true
    }

    func applySelectedPhoto(from selectedPhotoData: Data?) async {
        guard let selectedPhotoData else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        do {
            compressedPhotoData = try ImageCompression.compressedJPEGThumbnail(from: selectedPhotoData)
            inlineErrorMessage = nil
        } catch {
            logger.error("Photo load/compression failed: \(error.localizedDescription)")
            compressedPhotoData = nil
            inlineErrorMessage = nil
        }
    }

    func save() async throws -> ParkingSpot {
        isSaving = true
        defer { isSaving = false }
        inlineErrorMessage = nil

        let finalMeterDate = meterEnabled ? max(meterDate, minimumMeterDate) : nil
        let address = await GeocodingService.reverseGeocodeAddress(coordinate: draftCoordinate) ?? GeocodingService.coordinateFallbackString(for: draftCoordinate)

        let spot = ParkingSpot(
            name: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: draftCoordinate.latitude,
            longitude: draftCoordinate.longitude,
            expiresAt: finalMeterDate,
            photoData: compressedPhotoData,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: true,
            address: address,
            horizontalAccuracyMeters: initialHorizontalAccuracyMeters
        )

        do {
            try repository.insert(spot, makeActive: true)
            return spot
        } catch {
            logger.error("Parking spot save failed: \(error.localizedDescription)")
            inlineErrorMessage = error.localizedDescription
            throw error
        }
    }
}
