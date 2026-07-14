import Foundation

public enum ManagerOwnershipFilter: String, CaseIterable, Identifiable, Sendable {
    case unlocked
    case all
    case locked

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .unlocked: return "Unlocked"
        case .all: return "All"
        case .locked: return "Locked"
        }
    }
}

public enum ManagerSortOption: String, CaseIterable, Identifiable, Sendable {
    case recommended
    case name
    case level
    case rank
    case promotion
    case rarity
    case fragments

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .recommended: return "Recommended"
        case .name: return "Name"
        case .level: return "Highest Level"
        case .rank: return "Highest Rank"
        case .promotion: return "Highest Promotion"
        case .rarity: return "Rarity"
        case .fragments: return "Most Fragments"
        }
    }
}

@MainActor
struct ManagerListQuery {
    var searchText: String = ""
    var department: SMDepartment? = nil
    var ownership: ManagerOwnershipFilter = .unlocked
    var selectedRarities: Set<String> = []
    var upgradeReadyOnly: Bool = false
    var sort: ManagerSortOption = .recommended

    func apply(to allManagers: [SMProgress], progressService: SMProgressService) -> [SMProgress] {
        var items = allManagers

        switch ownership {
        case .unlocked:
            items = items.filter(\.unlocked)
        case .all:
            break
        case .locked:
            items = items.filter { !$0.unlocked }
        }

        if let department {
            items = items.filter { $0.areaEnum == department }
        }

        if !selectedRarities.isEmpty {
            items = items.filter { selectedRarities.contains($0.master.rarity.lowercased()) }
        }

        if upgradeReadyOnly {
            items = items.filter { manager in
                progressService.isRankUpReady(manager)
            }
        }

        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSearch.isEmpty {
            items = items.filter {
                $0.master.name.localizedCaseInsensitiveContains(normalizedSearch)
            }
        }

        switch sort {
        case .recommended:
            return items.sorted { lhs, rhs in
                let lhsScore = progressService.strengthScore(for: lhs)
                let rhsScore = progressService.strengthScore(for: rhs)
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                return lhs.master.name.localizedCaseInsensitiveCompare(rhs.master.name) == .orderedAscending
            }
        case .name:
            return items.sorted {
                $0.master.name.localizedCaseInsensitiveCompare($1.master.name) == .orderedAscending
            }
        case .level:
            return items.sorted {
                if $0.level != $1.level { return $0.level > $1.level }
                return $0.master.name.localizedCaseInsensitiveCompare($1.master.name) == .orderedAscending
            }
        case .rank:
            return items.sorted {
                if $0.rank != $1.rank { return $0.rank > $1.rank }
                return $0.master.name.localizedCaseInsensitiveCompare($1.master.name) == .orderedAscending
            }
        case .promotion:
            return items.sorted {
                if $0.promoted != $1.promoted { return $0.promoted > $1.promoted }
                return $0.master.name.localizedCaseInsensitiveCompare($1.master.name) == .orderedAscending
            }
        case .rarity:
            return items.sorted {
                let l = progressService.raritySortWeight(for: $0.master.rarity)
                let r = progressService.raritySortWeight(for: $1.master.rarity)
                if l != r { return l > r }
                return $0.master.name.localizedCaseInsensitiveCompare($1.master.name) == .orderedAscending
            }
        case .fragments:
            return items.sorted {
                if $0.fragments != $1.fragments { return $0.fragments > $1.fragments }
                return $0.master.name.localizedCaseInsensitiveCompare($1.master.name) == .orderedAscending
            }
        }
    }
}
