//
//  MapStyleOption.swift
//  parked
//

import CoreLocation
import MapKit
import SwiftUI

enum MapStyleOption: String, CaseIterable, Identifiable {
    case standard
    case satellite
    case minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return String(localized: "Standard", comment: "Map style title")
        case .satellite:
            return String(localized: "Satellite", comment: "Map style title")
        case .minimal:
            return String(localized: "Minimal", comment: "Map style title")
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard
        case .satellite:
            return .hybrid
        case .minimal:
            return .standard(pointsOfInterest: .excludingAll)
        }
    }
}

enum MapStylePreview {
    static let scenicCoordinate = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
}
