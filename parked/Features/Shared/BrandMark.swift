//
//  BrandMark.swift
//  parked
//

import SwiftUI

struct BrandMark: View {
    var body: some View {
        HStack(spacing: 8) {
            Image("ParkedLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(String(localized: "Parked.", comment: "App brand text"))
                .font(.headline)
        }
    }
}
