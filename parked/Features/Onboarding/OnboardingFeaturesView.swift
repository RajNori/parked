//
//  OnboardingFeaturesView.swift
//  parked
//

import SwiftUI

struct FeatureRow {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
}

struct OnboardingFeaturesView: View {
    private let features: [FeatureRow] = [
        FeatureRow(
            icon: "location.fill",
            tint: .blue,
            title: String(localized: "Precise GPS pin", comment: "Feature row title"),
            subtitle: String(localized: "Accurate to within 5 metres", comment: "Feature row subtitle")
        ),
        FeatureRow(
            icon: "camera.fill",
            tint: .green,
            title: String(localized: "Spot photo", comment: "Feature row title"),
            subtitle: String(localized: "Snap the floor, aisle or sign", comment: "Feature row subtitle")
        ),
        FeatureRow(
            icon: "timer",
            tint: .orange,
            title: String(localized: "Meter timer", comment: "Feature row title"),
            subtitle: String(localized: "Alerts before time runs out", comment: "Feature row subtitle")
        ),
    ]

    @State private var visibleRowIndexes: Set<Int> = []

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                Image(systemName: "map.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.green)
            }
            .frame(width: 120, height: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Illustration: map", comment: "VoiceOver onboarding features"))

            Text(String(localized: "Drop a pin. Add a photo. Done.", comment: "Onboarding features headline"))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(String(localized: "Everything you need, nothing you don't.", comment: "Onboarding features body"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, row in
                    featureRow(row)
                        .opacity(visibleRowIndexes.contains(index) ? 1 : 0)
                        .offset(y: visibleRowIndexes.contains(index) ? 0 : 20)
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .onAppear {
            for index in features.indices {
                let delay = Double(index) * 0.1
                withAnimation(.easeOut(duration: 0.45).delay(delay)) {
                    _ = visibleRowIndexes.insert(index)
                }
            }
        }
    }

    private func featureRow(_ row: FeatureRow) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(row.tint.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: row.icon)
                        .font(.title3)
                        .foregroundStyle(row.tint)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.headline)
                Text(row.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
