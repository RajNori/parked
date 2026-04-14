//
//  ActiveSpotCard.swift
//  parked
//

import SwiftUI

struct ActiveSpotCard: View {
    enum FocusField: Hashable {
        case name
        case notes
    }

    let spot: ParkingSpot
    let onDirections: () -> Void
    let onShare: () -> Void
    let onRemove: () -> Void
    let onSaveEdits: (_ name: String, _ notes: String) -> Void

    @State private var isEditing = false
    @State private var draftName = ""
    @State private var draftNotes = ""
    @State private var meterTimelineAnchor = Date()
    @FocusState private var focusedField: FocusField?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            details
            countdownSection
            actionRow
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            Task { @MainActor in
                meterTimelineAnchor = Date()
                resetDrafts()
            }
        }
        .onChange(of: spot.id) { _, _ in
            Task { @MainActor in
                meterTimelineAnchor = Date()
                resetDrafts()
            }
        }
        .onChange(of: spot.expiresAt?.timeIntervalSince1970 ?? 0) { _, _ in
            Task { @MainActor in
                meterTimelineAnchor = Date()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            if isEditing {
                TextField(
                    String(localized: "Spot name", comment: "ActiveSpotCard name field placeholder"),
                    text: $draftName
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)
            } else {
                Text(spot.name.isEmpty
                    ? String(localized: "Current Spot", comment: "Active spot fallback title")
                    : spot.name
                )
                .font(.title2.weight(.semibold))
            }

            Spacer(minLength: 0)

            if isEditing {
                Button(String(localized: "Save", comment: "ActiveSpotCard save edit")) {
                    onSaveEdits(draftName, draftNotes)
                    isEditing = false
                    focusedField = nil
                }
                .buttonStyle(.borderedProminent)

                Button(String(localized: "Cancel", comment: "ActiveSpotCard cancel edit")) {
                    isEditing = false
                    focusedField = nil
                    resetDrafts()
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    isEditing = true
                    focusedField = .name
                } label: {
                    Label(String(localized: "Edit", comment: "ActiveSpotCard edit"), systemImage: "pencil")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        Text(spot.address ?? GeocodingService.coordinateFallbackString(for: spot.coordinate))
            .font(.body)
            .foregroundStyle(.secondary)
            .lineLimit(2)

        if spot.isLowAccuracy {
            Label(String(localized: "Low accuracy", comment: "Low location accuracy badge"), systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }

        if isEditing {
            TextField(
                String(localized: "Notes", comment: "ActiveSpotCard notes field placeholder"),
                text: $draftNotes,
                axis: .vertical
            )
            .lineLimit(1...3)
            .textFieldStyle(.roundedBorder)
            .focused($focusedField, equals: .notes)
        } else if spot.notes.isEmpty == false {
            Text(spot.notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }

        Text(spot.savedAt.formatted(date: .abbreviated, time: .shortened))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var countdownSection: some View {
        if let expiresAt = spot.expiresAt {
            // REASON: Explicit periodic anchor (not `.now` each render) matches Phase 3 spec and stabilizes the schedule reference.
            // REASON: TimelineView.periodic and form controls here are iOS 17-safe; no iOS 18-only APIs in this file.
            TimelineView(.periodic(from: meterTimelineAnchor, by: 60.0)) { context in
                let remaining = max(0, expiresAt.timeIntervalSince(context.date))
                // REASON: Traffic light — green when more than 10 min left, orange 5–10 min, red under 5 min with pulse in red band only.
                let color: Color = remaining <= 300 ? .red : (remaining <= 600 ? .orange : .green)
                let pulseOpacity = remaining <= 300
                    ? (0.6 + 0.4 * abs(sin(context.date.timeIntervalSinceReferenceDate * 2.0)))
                    : 1.0

                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text(formattedCountdown(remaining))
                        .monospacedDigit()
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(color)
                .opacity(pulseOpacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    String(
                        localized: "Meter expires in \(voiceOverMinutes(remaining)) minutes",
                        comment: "VoiceOver meter countdown label in minutes"
                    )
                )
                .accessibilityValue(
                    String(
                        localized: "Time remaining \(formattedCountdown(remaining))",
                        comment: "VoiceOver meter countdown value"
                    )
                )
            }
        }
    }

    private var actionRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    actionButton(title: String(localized: "Get Directions", comment: "ActiveSpotCard directions action"), systemImage: "figure.walk", style: .prominent, action: onDirections)
                    actionButton(title: String(localized: "Share", comment: "ActiveSpotCard share action"), systemImage: "square.and.arrow.up", style: .normal, action: onShare)
                    actionButton(title: String(localized: "Remove", comment: "ActiveSpotCard remove action"), systemImage: "trash", style: .destructive, action: onRemove)
                }
            } else {
                HStack(spacing: 12) {
                    actionButton(title: String(localized: "Get Directions", comment: "ActiveSpotCard directions action"), systemImage: "figure.walk", style: .prominent, action: onDirections)
                    actionButton(title: String(localized: "Share", comment: "ActiveSpotCard share action"), systemImage: "square.and.arrow.up", style: .normal, action: onShare)
                    actionButton(title: String(localized: "Remove", comment: "ActiveSpotCard remove action"), systemImage: "trash", style: .destructive, action: onRemove)
                }
            }
        }
    }

    private enum ActionButtonStyle {
        case prominent
        case normal
        case destructive
    }

    private func actionButton(title: String, systemImage: String, style: ActionButtonStyle, action: @escaping () -> Void) -> some View {
        Group {
            if style == .prominent {
                Button(action: action) {
                    actionLabel(title: title, systemImage: systemImage, style: style)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) {
                    actionLabel(title: title, systemImage: systemImage, style: style)
                }
                .buttonStyle(.bordered)
                .modifier(ActionTintModifier(isDestructive: style == .destructive))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func actionLabel(title: String, systemImage: String, style: ActionButtonStyle) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .fontWeight(style == .prominent ? .medium : .regular)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    private func resetDrafts() {
        draftName = spot.name
        draftNotes = spot.notes
    }

    private func formattedCountdown(_ remaining: TimeInterval) -> String {
        let total = Int(remaining.rounded(.down))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func voiceOverMinutes(_ remaining: TimeInterval) -> Int {
        max(0, Int(ceil(remaining / 60.0)))
    }
}

private struct ActionTintModifier: ViewModifier {
    let isDestructive: Bool

    func body(content: Content) -> some View {
        if isDestructive {
            content.tint(.red)
        } else {
            content
        }
    }
}
