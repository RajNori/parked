//
//  OnboardingLayout.swift
//  parked
//

import SwiftUI

/// Constrains onboarding content width in landscape (HIG-friendly reading measure).
struct OnboardingLayout<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            HStack {
                Spacer(minLength: 0)
                content()
                    .frame(maxWidth: isLandscape ? 440 : .infinity)
                Spacer(minLength: 0)
            }
            .frame(minHeight: proxy.size.height)
        }
    }
}
