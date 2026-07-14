@testable import MineOpsCompanionFeature
import Foundation
import Testing

@Suite("SMProgressService Sync Behavior")
struct SMProgressServiceSyncTests {

    @Test("Kolibri values replace larger local level/rank/promotion")
    func kolibriReplacesLocalValues() async throws {
        // Create a minimal master entry
        let entry = SMMasterEntry(
            id: "test_manager",
            name: "Test Manager",
            rarity: "common",
            area: "mineshaft",
            gameId: 42,
            sprite: "test",
            elements: [],
            passives: [],
            activeL1: 1.0,
            activeL100: 100.0,
            cooldown: 60,
            duration: 10,
            descriptionLong: nil,
            descriptionShort: nil,
            placeholderIndices: nil,
            legacyGameIds: nil,
            rental: nil,
            maxLevel: nil
        )

        // Inject master data for deterministic testing
        SMMasterDataService.shared.masterData = [entry]

        // Initialize progress defaults
        await SMProgressService.shared.initialize()

        // Sanity: should have one progress entry
        #expect(SMProgressService.shared.totalCount == 1)

        // Update locally to large values
        SMProgressService.shared.update(id: entry.id, rank: 5, level: 50, promoted: 4, unlocked: true)

        // Create a Kolibri manager payload with smaller values
        let manager = ManagerData(
            id: "42",
            name: "Test Manager",
            rarity: "common",
            rank: 0,
            level: 16,
            promotion: 0,
            assignedTo: nil,
            fragments: 3,
            abilities: nil
        )

        // Apply authoritative sync
        await SMProgressService.shared.applySyncData(managers: [manager])

        // Verify the progress entry now reflects Kolibri values (not preserved larger local values)
        let updated = SMProgressService.shared.progress.first { $0.master.gameId == 42 }
        #expect(updated != nil)
        #expect(updated!.level == 16)
        #expect(updated!.rank == 0)
        #expect(updated!.promoted == 0)
        #expect(updated!.fragments == 3)
        #expect(updated!.unlocked == true)
    }
}
