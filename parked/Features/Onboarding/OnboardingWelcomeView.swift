//
//  OnboardingWelcomeView.swift
//  parked
//

import SwiftUI

struct OnboardingWelcomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let onPrimary: () -> Void
    let onSkipToPermissions: () -> Void

    private var illustrationSize: CGFloat {
        // REASON: iPhone SE / narrow width — scale hero without shrinking body type.
        horizontalSizeClass == .compact ? 90 : 120
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Image("ParkedLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
            .frame(width: illustrationSize, height: illustrationSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Parked logo", comment: "VoiceOver onboarding welcome"))

            Text(String(localized: "Never lose your car again.", comment: "Onboarding welcome headline"))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(
                String(
                    localized: "One tap saves your exact spot. Walk away confident. We'll guide you straight back.",
                    comment: "Onboarding welcome body"
                )
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button(String(localized: "Get started", comment: "Onboarding primary CTA")) {
                    onPrimary()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(String(localized: "I already have a spot", comment: "Onboarding skip to permissions")) {
                    onSkipToPermissions()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }
}
