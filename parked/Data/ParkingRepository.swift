//
//  ParkingRepository.swift
//  parked
//

import Foundation
import OSLog
import SwiftData

/// SwiftData access for parking spots; all persistence errors propagate to callers.
@MainActor
final class ParkingRepository {
    private let modelContext: ModelContext
    private let logger = ParkedLog.repository

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func spot(id: UUID) throws -> ParkingSpot? {
        let sid = id
        var descriptor = FetchDescriptor<ParkingSpot>(
            predicate: #Predicate<ParkingSpot> { $0.id == sid }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func activeSpot() throws -> ParkingSpot? {
        var descriptor = FetchDescriptor<ParkingSpot>(
            predicate: #Predicate { $0.isActive == true }
        )
        descriptor.fetchLimit = 2
        let spots = try modelContext.fetch(descriptor)
        if spots.count > 1 {
            logger.warning("Multiple active spots found; returning first only.")
        }
        return spots.first
    }

    /// REASON: Enforces at most one active spot before inserting or activating another.
    func deactivateAllActiveSpots() throws {
        let descriptor = FetchDescriptor<ParkingSpot>(
            predicate: #Predicate { $0.isActive == true }
        )
        for spot in try modelContext.fetch(descriptor) {
            spot.isActive = false
        }
    }

    func insert(_ spot: ParkingSpot, makeActive: Bool) throws {
        if makeActive {
            try deactivateAllActiveSpots()
            spot.isActive = true
        }
        modelContext.insert(spot)
        try modelContext.save()
    }

    func delete(_ spot: ParkingSpot) throws {
        modelContext.delete(spot)
        try modelContext.save()
    }

    func save() throws {
        try modelContext.save()
    }

    func allSpotsSortedBySavedAtDescending() throws -> [ParkingSpot] {
        let descriptor = FetchDescriptor<ParkingSpot>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
