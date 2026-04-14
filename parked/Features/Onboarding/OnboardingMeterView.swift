//
//  OnboardingMeterView.swift
//  parked
//

import SwiftUI

struct OnboardingMeterView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var pulseToken = 0

    private var illustrationSize: CGFloat {
        horizontalSizeClass == .compact ? 90 : 120
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: illustrationSize * 0.38, weight: .medium))
                    .foregroundStyle(.red)
                    // REASON: iOS 17–compatible symbol animation (no iOS 18-only effects).
                    .symbolEffect(.pulse, value: pulseToken)
            }
            .frame(width: illustrationSize, height: illustrationSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Illustration: meter clock", comment: "VoiceOver onboarding meter"))
            .onAppear {
                pulseToken += 1
            }

            Text(String(localized: "No more parking tickets.", comment: "Onboarding meter headline"))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(
                String(
                    localized: "Set your meter. We'll ping you at 15, 10, and 5 minutes — with enough time to get back.",
                    comment: "Onboarding meter body"
                )
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            meterDemoCard
                .padding(.horizontal, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var meterDemoCard: some View {
        // REASON: `.periodic` is the iOS 17–compatible schedule; avoid newer `TimelineView` animation overloads.
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // REASON: looping shrink for demo only — not tied to a real countdown timer.
            let phase = (sin(t * 1.1) + 1) / 2
            let fillAmount = 0.06 + phase * 0.12

            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "4:52 remaining", comment: "Onboarding mock meter countdown"))
                    .font(.title3.monospacedDigit().weight(.semibold))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.red.opacity(0.15))
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.red)
                            .frame(width: max(4, geo.size.width * fillAmount))
                    }
                }
                .frame(height: 10)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(height: 120)
    }
}
