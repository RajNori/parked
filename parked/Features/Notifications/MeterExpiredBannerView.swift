//
//  MeterExpiredBannerView.swift
//  parked
//

import CoreLocation
import MapKit
import SwiftUI

struct MeterExpiredBannerPayload: Equatable {
    let spotId: String
    let latitude: Double
    let longitude: Double
    let address: String
}

struct MeterExpiredBannerView: View {
    let payload: MeterExpiredBannerPayload
    let onDismiss: () -> Void
    let onGetDirections: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Meter expired", comment: "Meter expired banner title"))
                        .font(.headline)
                    Text(payload.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(String(localized: "Dismiss", comment: "Dismiss meter banner"))
            }
            Button(String(localized: "Get Directions", comment: "Meter expired banner directions")) {
                onGetDirections()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    static func openWalkingDirections(payload: MeterExpiredBannerPayload) {
        let coordinate = CLLocationCoordinate2D(latitude: payload.latitude, longitude: payload.longitude)
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        destination.name = String(localized: "Parked Car", comment: "Default destination name for meter expiry directions")
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        destination.openInMaps(launchOptions: launchOptions)
    }
}
