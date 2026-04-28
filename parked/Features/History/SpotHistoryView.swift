//
//  SpotHistoryView.swift
//  parked
//

import MapKit
import SwiftData
import SwiftUI
import UIKit

struct SpotHistoryView: View {
    @Environment(\.parkedAppState) private var appState
    @Query(
        filter: #Predicate<ParkingSpot> { $0.isActive == false },
        sort: [SortDescriptor(\ParkingSpot.savedAt, order: .reverse)]
    )
    private var inactiveSpots: [ParkingSpot]

    @State private var searchText = ""
    @State private var selectedSpot: SpotSelection?
    @State private var pendingDeletion: SpotSelection?
    @State private var inlineErrorMessage: String?

    private var filteredSpots: [ParkingSpot] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.isEmpty == false else { return inactiveSpots }
        return inactiveSpots.filter { spot in
            let nameMatch = spot.name.localizedStandardContains(needle)
            let addressMatch = (spot.address ?? "").localizedStandardContains(needle)
            return nameMatch || addressMatch
        }
    }

    var body: some View {
        Group {
            if filteredSpots.isEmpty {
                emptyState
            } else {
                List {
                    if let inlineErrorMessage {
                        Text(inlineErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    ForEach(filteredSpots) { spot in
                        Button {
                            selectedSpot = SpotSelection(id: spot.id)
                        } label: {
                            SpotHistoryRow(spot: spot)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = SpotSelection(id: spot.id)
                            } label: {
                                Label(String(localized: "Delete", comment: "Delete history row action"), systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(String(localized: "History", comment: "Spot history navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            prompt: Text(String(localized: "Search by nickname or address", comment: "History search field prompt"))
        )
        .sheet(item: $selectedSpot) { selection in
            if let spot = inactiveSpots.first(where: { $0.id == selection.id }) {
                SpotHistoryDetailView(spot: spot)
            }
        }
        .alert(
            String(localized: "Delete saved spot?", comment: "Delete saved spot alert title"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { newValue in
                    if newValue == false {
                        pendingDeletion = nil
                    }
                }
            )
        ) {
            Button(String(localized: "Cancel", comment: "Delete saved spot cancel"), role: .cancel) {
                pendingDeletion = nil
            }
            Button(String(localized: "Delete", comment: "Delete saved spot confirm"), role: .destructive) {
                deletePendingSpot()
            }
        } message: {
            Text(String(localized: "This removes this saved entry from your history.", comment: "Delete saved spot alert body"))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            BrandMark()
                .padding(.bottom, 4)
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)
            Text(
                searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? String(localized: "No saved history yet", comment: "History empty title")
                    : String(localized: "No matching spots", comment: "History search empty title")
            )
            .font(.title3.weight(.semibold))
            Text(
                searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? String(localized: "Past spots appear here when you save a new one and the previous spot becomes inactive.", comment: "History empty body")
                    : String(localized: "Try a different nickname or address.", comment: "History search empty body")
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func deletePendingSpot() {
        guard let pendingDeletion, let appState else { return }
        guard let spot = inactiveSpots.first(where: { $0.id == pendingDeletion.id }) else {
            self.pendingDeletion = nil
            return
        }
        do {
            try appState.repository.delete(spot)
            self.pendingDeletion = nil
            inlineErrorMessage = nil
        } catch {
            inlineErrorMessage = error.localizedDescription
            self.pendingDeletion = nil
        }
    }
}

private struct SpotHistoryRow: View {
    let spot: ParkingSpot

    // FIX: Cache the formatter as a static to avoid allocating a new
    // RelativeDateTimeFormatter on every render pass (was causing frame
    // pressure when scrolling a long history list).
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private var title: String {
        if spot.name.isEmpty == false { return spot.name }
        if let address = spot.address, address.isEmpty == false { return address }
        return GeocodingService.coordinateFallbackString(for: spot.coordinate)
    }

    private var subtitle: String {
        let relative = Self.relativeDateFormatter.localizedString(for: spot.savedAt, relativeTo: .now)
        return String(localized: "Saved \(relative)", comment: "History row relative save time")
    }

    var body: some View {
        HStack(spacing: 12) {
            SpotSnapshotThumbnail(spot: spot)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let address = spot.address, address.isEmpty == false {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let addressPart = spot.address ?? GeocodingService.coordinateFallbackString(for: spot.coordinate)
        let formatted = spot.savedAt.formatted(date: .abbreviated, time: .shortened)
        return String(
            localized: "\(addressPart), saved \(formatted), \(subtitle)",
            comment: "VoiceOver combined history row label"
        )
    }
}

// MARK: - SpotSnapshotThumbnail

private struct SpotSnapshotThumbnail: View {
    let spot: ParkingSpot

    // FIX: Declare both state properties as @MainActor-isolated by placing this
    // view in a @MainActor context (SwiftUI views are always on main actor).
    // The original `loadSnapshotIfNeeded()` mutated `isLoading` and `image`
    // around an `await` without explicit main-actor hops, which could write
    // these @State values from a non-main executor and trigger SwiftUI
    // "publishing changes from background threads" warnings / state corruption.
    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemFill))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "map")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: spot.id) {
            await loadSnapshotIfNeeded()
        }
    }

    // FIX: All mutations of `isLoading` and `image` now happen on @MainActor
    // via explicit `await MainActor.run { }` blocks around the await boundary.
    // Previously the implicit `await` in `SpotSnapshotCache.shared.image(...)`
    // could resume on a non-main thread, causing the subsequent `image = snapshot`
    // write to hit SwiftUI's state from a background executor.
    @MainActor
    private func loadSnapshotIfNeeded() async {
        guard image == nil, isLoading == false else { return }
        isLoading = true
        defer {
            // `defer` runs on the same actor context as the surrounding scope —
            // because the function is @MainActor, this is always the main actor.
            isLoading = false
        }
        let latitude = spot.latitude
        let longitude = spot.longitude
        let size = CGSize(width: 180, height: 180)
        // `await` suspends here; when it resumes we are back on MainActor
        // because the actor hop happens inside `SpotSnapshotCache` and the
        // return is just a value type (UIImage?), not an actor-bound reference.
        if let snapshot = await SpotSnapshotCache.shared.image(
            id: spot.id,
            latitude: latitude,
            longitude: longitude,
            size: size
        ) {
            image = snapshot   // safe: always on @MainActor
        }
    }
}

// MARK: - SpotSnapshotCache

private actor SpotSnapshotCache {
    static let shared = SpotSnapshotCache()

    private var images: [UUID: UIImage] = [:]

    func image(id: UUID, latitude: Double, longitude: Double, size: CGSize) async -> UIImage? {
        if let cached = images[id] { return cached }
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard let snapshot = await Self.generate(center: center, size: size) else { return nil }
        images[id] = snapshot
        return snapshot
    }

    private static func generate(center: CLLocationCoordinate2D, size: CGSize) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.size = size
        options.mapType = .standard
        options.showsBuildings = true
        options.camera = MKMapCamera(
            lookingAtCenter: center,
            fromDistance: 220,
            pitch: 0,
            heading: 0
        )
        let snapshotter = MKMapSnapshotter(options: options)
        return await withCheckedContinuation { continuation in
            snapshotter.start(with: .global(qos: .userInitiated)) { snapshot, _ in
                continuation.resume(returning: snapshot?.image)
            }
        }
    }
}

// MARK: - Supporting types

private struct SpotSelection: Identifiable, Hashable {
    let id: UUID
}

private struct SpotHistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let spot: ParkingSpot

    // FIX: Cache the DateFormatter as a static to avoid re-allocating on every
    // render (was flagged as a perf smell by Cursor's analysis).
    private static let savedAtFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var title: String {
        if spot.name.isEmpty == false { return spot.name }
        if let address = spot.address, address.isEmpty == false { return address }
        return String(localized: "Saved spot", comment: "History detail fallback title")
    }

    private var formattedSavedAt: String {
        Self.savedAtFormatter.string(from: spot.savedAt)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SpotSnapshotThumbnail(spot: spot)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Group {
                        Text(title)
                            .font(.title3.weight(.semibold))
                        if let address = spot.address, address.isEmpty == false {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(
                            String(
                                localized: "Saved on \(formattedSavedAt)",
                                comment: "History detail saved date"
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    if spot.notes.isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "Notes", comment: "History detail notes header"))
                                .font(.headline)
                            Text(spot.notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let data = spot.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button {
                        let destination = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
                        destination.name = title
                        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                    } label: {
                        Label(
                            String(localized: "Open in Maps", comment: "History detail maps action"),
                            systemImage: "arrow.triangle.turn.up.right.diamond"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(18)
            }
            .navigationTitle(String(localized: "Spot details", comment: "History detail title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done", comment: "History detail done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
