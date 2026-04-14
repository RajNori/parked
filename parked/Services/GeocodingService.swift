//
//  GeocodingService.swift
//  parked
//

import CoreLocation
import Foundation
import OSLog

enum GeocodingService {
    private static let logger = ParkedLog.geocoding

    static func reverseGeocodeAddress(coordinate: CLLocationCoordinate2D) async -> String? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error {
                    logger.error("Reverse geocode failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: format(placemark: placemark))
            }
        }
    }

    static func coordinateFallbackString(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    private static func format(placemark: CLPlacemark) -> String? {
        var parts: [String] = []
        if let subThoroughfare = placemark.subThoroughfare, let thoroughfare = placemark.thoroughfare {
            parts.append("\(subThoroughfare) \(thoroughfare)")
        } else if let thoroughfare = placemark.thoroughfare {
            parts.append(thoroughfare)
        }
        if let locality = placemark.locality {
            parts.append(locality)
        }
        if parts.isEmpty, let name = placemark.name {
            parts.append(name)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
