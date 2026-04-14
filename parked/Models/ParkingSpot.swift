//
//  ParkingSpot.swift
//  parked
//

import CoreLocation
import Foundation
import SwiftData

@Model
final class ParkingSpot {
    var id: UUID
    var name: String
    /// REASON: SwiftData persists scalars; MapKit uses `coordinate` via computed property.
    var latitude: Double
    var longitude: Double
    var savedAt: Date
    var expiresAt: Date?
    @Attribute(.externalStorage) var photoData: Data?
    var notes: String
    var isActive: Bool
    var address: String?
    var horizontalAccuracyMeters: Double?

    init(
        id: UUID = UUID(),
        name: String = "",
        latitude: Double,
        longitude: Double,
        savedAt: Date = .now,
        expiresAt: Date? = nil,
        photoData: Data? = nil,
        notes: String = "",
        isActive: Bool = false,
        address: String? = nil,
        horizontalAccuracyMeters: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.savedAt = savedAt
        self.expiresAt = expiresAt
        self.photoData = photoData
        self.notes = notes
        self.isActive = isActive
        self.address = address
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
    }
}

extension ParkingSpot {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func applyCoordinate(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var isLowAccuracy: Bool {
        guard let horizontalAccuracyMeters else { return false }
        return horizontalAccuracyMeters >= 100
    }
}
