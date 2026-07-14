@testable import MineOpsCompanionFeature
import Foundation
import Testing

@MainActor
@Suite("Manager Filtering")
struct ManagerFilteringTests {

    @Test("Default filter returns unlocked only")
    func defaultReturnsUnlockedOnly() async {
        let service = await seededProgressService()

        let query = ManagerListQuery()
        let result = query.apply(to: service.progress, progressService: service)

        #expect(result.isEmpty == false)
        #expect(result.allSatisfy(\.unlocked))
    }

    @Test("Department filter narrows results correctly")
    func departmentFilterWorks() async {
        let service = await seededProgressService()

        var query = ManagerListQuery()
        query.ownership = .all
        query.department = .elevator
        let result = query.apply(to: service.progress, progressService: service)

        #expect(result.isEmpty == false)
        #expect(result.allSatisfy { $0.areaEnum == .elevator })
    }

    @Test("Search combines with ownership filter")
    func searchCombinesWithOwnership() async {
        let service = await seededProgressService()

        var query = ManagerListQuery()
        query.ownership = .locked
        query.searchText = "gamma"

        let result = query.apply(to: service.progress, progressService: service)

        #expect(result.count == 1)
        #expect(result.first?.master.name == "Gamma")
        #expect(result.first?.unlocked == false)
    }

    @Test("Recommended sort is deterministic with name tie-breaker")
    func recommendedSortDeterministicTieBreaker() async {
        let service = await seededProgressService()

        var query = ManagerListQuery()
        query.ownership = .all
        query.sort = .recommended

        let result = query.apply(to: service.progress, progressService: service)
        let alphaIndex = result.firstIndex(where: { $0.master.name == "Alpha" })
        let betaIndex = result.firstIndex(where: { $0.master.name == "Beta" })

        #expect(alphaIndex != nil)
        #expect(betaIndex != nil)
        #expect(alphaIndex! < betaIndex!)
    }

    private func seededProgressService() async -> SMProgressService {
        let entries: [SMMasterEntry] = [
            .init(
                id: "alpha",
                name: "Alpha",
                rarity: "rare",
                area: "mineshaft",
                gameId: 101,
                sprite: "alpha",
                elements: [],
                passives: [],
                activeL1: 1,
                activeL100: 100,
                cooldown: 60,
                duration: 10,
                descriptionLong: nil,
                descriptionShort: nil,
                placeholderIndices: nil,
                legacyGameIds: nil,
                rental: nil,
                maxLevel: nil
            ),
            .init(
                id: "beta",
                name: "Beta",
                rarity: "rare",
                area: "elevator",
                gameId: 102,
                sprite: "beta",
                elements: [],
                passives: [],
                activeL1: 1,
                activeL100: 100,
                cooldown: 60,
                duration: 10,
                descriptionLong: nil,
                descriptionShort: nil,
                placeholderIndices: nil,
                legacyGameIds: nil,
                rental: nil,
                maxLevel: nil
            ),
            .init(
                id: "gamma",
                name: "Gamma",
                rarity: "common",
                area: "warehouse",
                gameId: 103,
                sprite: "gamma",
                elements: [],
                passives: [],
                activeL1: 1,
                activeL100: 100,
                cooldown: 60,
                duration: 10,
                descriptionLong: nil,
                descriptionShort: nil,
                placeholderIndices: nil,
                legacyGameIds: nil,
                rental: nil,
                maxLevel: nil
            )
        ]

        SMMasterDataService.shared.masterData = entries

        // Reset to defaults: all locked.
        await SMProgressService.shared.applySyncData(managers: [])

        // Unlock Alpha and Beta with equal scoring values to test deterministic tie-breaker.
        let synced: [ManagerData] = [
            .init(id: "101", name: "Alpha", rarity: "rare", rank: 1, level: 10, promotion: 1, assignedTo: nil, fragments: 5, abilities: nil),
            .init(id: "102", name: "Beta", rarity: "rare", rank: 1, level: 10, promotion: 1, assignedTo: nil, fragments: 5, abilities: nil)
        ]
        await SMProgressService.shared.applySyncData(managers: synced)

        return SMProgressService.shared
    }
}
