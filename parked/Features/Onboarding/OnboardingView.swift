//
//  OnboardingView.swift
//  parked
//

import SwiftUI

struct OnboardingView: View {
    @Bindable var locationManager: LocationManager

    @AppStorage(AppSettings.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        OnboardingLayout {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    OnboardingWelcomeView(
                        onPrimary: { advanceFromWelcome(next: 1) },
                        onSkipToPermissions: { jumpToPermissions() }
                    )
                    .tag(0)

                    OnboardingFeaturesView()
                    .tag(1)

                    OnboardingMeterView()
                    .tag(2)

                    OnboardingPermissionsView(locationManager: locationManager)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: currentPage)

                if currentPage == 0 {
                    // REASON: Welcome screen supplies its own primary/secondary CTAs per spec.
                    pageDots
                        .padding(.bottom, 24)
                } else if currentPage < 3 {
                    bottomChrome
                } else {
                    pageDots
                        .padding(.bottom, 24)
                }
            }
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 12) {
            pageDots
            HStack {
                Button(String(localized: "Back", comment: "Onboarding back")) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        currentPage = max(0, currentPage - 1)
                    }
                    ParkedHaptics.lightImpact()
                }
                .disabled(currentPage == 0)
                .opacity(currentPage == 0 ? 0.4 : 1)

                Spacer()

                Button(String(localized: "Next", comment: "Onboarding next")) {
                    advanceTo(page: currentPage + 1)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)

            Button(String(localized: "Skip", comment: "Onboarding skip")) {
                jumpToPermissions()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< 4, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
            }
        }
    }

    private func advanceFromWelcome(next: Int) {
        advanceTo(page: next)
    }

    private func advanceTo(page: Int) {
        let next = min(3, page)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            currentPage = next
        }
        ParkedHaptics.lightImpact()
    }

    private func jumpToPermissions() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            currentPage = 3
        }
        ParkedHaptics.lightImpact()
    }
}
