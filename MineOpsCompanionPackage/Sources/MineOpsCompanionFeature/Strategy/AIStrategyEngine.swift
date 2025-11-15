import Foundation
import UIKit

@MainActor
final class AIStrategyEngine: ObservableObject {
    enum StrategyError: LocalizedError {
        case missingAPIKey
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "OPENAI_API_KEY not found in environment variables."
            case .invalidResponse: return "Unable to decode strategy response."
            }
        }
    }

    static let shared = AIStrategyEngine()

    @Published private(set) var lastResult: StrategyResponse?
    @Published private(set) var isLoading = false

    private init() {}

    // MARK: - Public API (maintaining compatibility)
    
    @discardableResult
    func generateStrategy(
        mineName: String,
        mineLevel: Int,
        shaftLevel: Int,
        selectedManagers: [String],
        screenshots: [UIImage],
        notes: String?
    ) async throws -> StrategyResponse {
        isLoading = true
        defer { isLoading = false }
        
        // For now, convert string names to RecognizedSM placeholders
        // In a real scenario, this would come from the roster
        let directory = try? SMDirectory.load()
        let roster = selectedManagers.compactMap { managerName -> RecognizedSM? in
            guard let entry = directory?.first(where: { $0.name == managerName }) else {
                return nil
            }
            // Create a minimal RecognizedSM for strategy generation
            return RecognizedSM(
                sourceImage: UIImage(),
                rawText: managerName,
                level: nil,
                directoryMatch: entry,
                resolvedName: managerName,
                stats: SMStats()
            )
        }
        
        let strategy = Self.generate(from: roster)
        lastResult = strategy
        return strategy
    }
    
    // MARK: - Core Strategy Generation
    
    /// Generate strategy from a roster of RecognizedSM managers
    static func generate(from roster: [RecognizedSM]) -> StrategyResponse {
        let warehouseManagers = bestWarehouseManagers(from: roster, maxCount: 2)
        let elevatorManagers = bestElevatorManagers(from: roster, maxCount: 2)
        let mineshaftManagers = bestMineshaftManagers(from: roster, maxCount: 4)
        
        let comboName = determineComboName(
            warehouse: warehouseManagers,
            elevator: elevatorManagers,
            mineshaft: mineshaftManagers
        )
        
        let allRecommended = (warehouseManagers + elevatorManagers + mineshaftManagers)
            .map { $0.directoryMatch?.name ?? $0.resolvedName }
        
        let summary = buildStrategySummary(
            warehouse: warehouseManagers,
            elevator: elevatorManagers,
            mineshaft: mineshaftManagers,
            roster: roster
        )
        
        let multiplier = estimateMultiplier(
            warehouse: warehouseManagers,
            elevator: elevatorManagers,
            mineshaft: mineshaftManagers
        )
        
        return StrategyResponse(
            comboName: comboName,
            recommendedManagers: allRecommended,
            strategySummary: summary,
            estimatedMultiplier: multiplier
        )
    }
    
    // MARK: - Manager Selection by Building
    
    private static func bestWarehouseManagers(from roster: [RecognizedSM], maxCount: Int) -> [RecognizedSM] {
        let scored = roster
            .map { manager in
                ScoredManager(manager: manager, score: scoreForWarehouse(manager, roster: roster))
            }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
        
        return Array(scored.prefix(maxCount).map { $0.manager })
    }
    
    private static func bestElevatorManagers(from roster: [RecognizedSM], maxCount: Int) -> [RecognizedSM] {
        let scored = roster
            .map { manager in
                ScoredManager(manager: manager, score: scoreForElevator(manager, roster: roster))
            }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
        
        return Array(scored.prefix(maxCount).map { $0.manager })
    }
    
    private static func bestMineshaftManagers(from roster: [RecognizedSM], maxCount: Int) -> [RecognizedSM] {
        let scored = roster
            .map { manager in
                ScoredManager(manager: manager, score: scoreForMineshaft(manager, roster: roster))
            }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
        
        return Array(scored.prefix(maxCount).map { $0.manager })
    }
    
    // MARK: - Scoring Functions
    
    private static func scoreForWarehouse(_ sm: RecognizedSM, roster: [RecognizedSM]) -> Double {
        let name = sm.directoryMatch?.name ?? sm.resolvedName
        let dept = sm.directoryMatch?.department ?? ""
        var score = 0.0
        
        // Top priority: Mr. Edmund
        if name == "Mr. Edmund" {
            score += 1000.0
        }
        // Synergy partner: Luxario (not in current directory, but check for future)
        else if name == "Luxario" {
            score += 800.0
        }
        // Cost reducers for upgrade phases
        else if name == "Mark" || name == "Mrs. Goodman" || name == "Goodman Jr." {
            score += 500.0
        }
        // Other warehouse managers
        else if dept == "warehouse" {
            score += 300.0
        }
        
        // Role match bonus
        if dept == "warehouse" {
            score += 200.0
        }
        
        // Level bonus
        if let level = sm.level {
            score += Double(level) * 10.0
        }
        
        // Boost from directory
        if let mult = sm.directoryMatch?.active?.multiplier {
            score += mult * 0.5
        }
        
        // Synergy bonus
        score += synergyBonus(for: sm, in: roster) * 100.0
        
        return score
    }
    
    private static func scoreForElevator(_ sm: RecognizedSM, roster: [RecognizedSM]) -> Double {
        let name = sm.directoryMatch?.name ?? sm.resolvedName
        let dept = sm.directoryMatch?.department ?? ""
        var score = 0.0
        
        // Top speeders
        if name == "Damian Jones" {
            score += 1000.0
        } else if name == "Sojo" {
            score += 950.0
        }
        // Strong supporting elevator options
        else if name == "Lee Vatori" || name == "Jeff" || name == "Zi Galvani" {
            score += 700.0
        }
        // Cost reducers for early elevator upgrades
        else if name == "Mark" || name == "Mrs. Goodman" || name == "Goodman Jr." {
            score += 400.0
        }
        // Other elevator managers (Transport role maps to elevator)
        else if dept == "elevator" {
            score += 300.0
        }
        
        // Role match bonus
        if dept == "elevator" {
            score += 200.0
        }
        
        // Level bonus
        if let level = sm.level {
            score += Double(level) * 10.0
        }
        
        // Boost from directory
        if let mult = sm.directoryMatch?.active?.multiplier {
            score += mult * 0.5
        }
        
        // Synergy bonus
        score += synergyBonus(for: sm, in: roster) * 100.0
        
        return score
    }
    
    private static func scoreForMineshaft(_ sm: RecognizedSM, roster: [RecognizedSM]) -> Double {
        let name = sm.directoryMatch?.name ?? sm.resolvedName
        let dept = sm.directoryMatch?.department ?? ""
        var score = 0.0
        
        // Top burst/DPS managers
        if name == "H4V0C" {
            score += 1000.0
        } else if name == "Freesia" {
            score += 950.0
        } else if name == "Thalia" {
            score += 900.0
        } else if name == "Cliff Walker" {
            score += 800.0
        } else if name == "Lavender Wick" {
            score += 780.0
        } else if name == "Ranger Sue" {
            score += 760.0
        } else if name == "Blingsley" {
            score += 740.0
        } else if name == "Chris Capella" {
            score += 720.0
        } else if name == "Al Titude" {
            score += 700.0
        }
        // Other mineshaft managers
        else if dept == "mineshaft" {
            score += 300.0
        }
        
        // Role match bonus
        if dept == "mineshaft" {
            score += 200.0
        }
        
        // Level bonus (higher weight for mineshaft as levels matter more)
        if let level = sm.level {
            score += Double(level) * 15.0
        }
        
        // Boost from directory
        if let mult = sm.directoryMatch?.active?.multiplier {
            score += mult * 0.8
        }
        
        // Strong synergy bonus for known combos
        let synergyMult = synergyBonus(for: sm, in: roster)
        if synergyMult > 0 {
            score += synergyMult * 200.0  // Higher weight for mineshaft synergies
        }
        
        return score
    }
    
    // MARK: - Synergy Detection
    
    private static func synergyBonus(for sm: RecognizedSM, in roster: [RecognizedSM]) -> Double {
        let name = sm.directoryMatch?.name ?? sm.resolvedName
        var bonus = 0.0
        
        // Check directory synergies
        if let synergyList = sm.directoryMatch?.passives?.first(where: { $0.kind.contains("synergy") }) {
            // Directory has synergy info
            bonus += 1.0
        }
        
        // Known synergy combos
        let synergyPairs: [(String, String)] = [
            ("Thalia", "H4V0C"),
            ("Thalia", "Freesia"),
            ("H4V0C", "Freesia"),
            ("Mr. Edmund", "Lee Vatori"),
            ("Mr. Edmund", "Mrs. Goodman"),
            ("Mr. Edmund", "Luxario"),
            ("Mrs. Goodman", "Goodman Jr."),
            ("Damian Jones", "Chris Capella"),
            ("Cliff Walker", "Dr. Lilly")
        ]
        
        for (first, second) in synergyPairs {
            if name == first && hasManager(second, in: roster) {
                bonus += 1.0
            } else if name == second && hasManager(first, in: roster) {
                bonus += 1.0
            }
        }
        
        return bonus
    }
    
    private static func hasManager(_ name: String, in roster: [RecognizedSM]) -> Bool {
        roster.contains { sm in
            (sm.directoryMatch?.name ?? sm.resolvedName) == name
        }
    }
    
    // MARK: - Strategy Summary Generation
    
    private static func determineComboName(
        warehouse: [RecognizedSM],
        elevator: [RecognizedSM],
        mineshaft: [RecognizedSM]
    ) -> String {
        let warehouseNames = warehouse.map { $0.directoryMatch?.name ?? $0.resolvedName }
        let elevatorNames = elevator.map { $0.directoryMatch?.name ?? $0.resolvedName }
        let mineshaftNames = mineshaft.map { $0.directoryMatch?.name ?? $0.resolvedName }
        
        // Thalia + Freesia + H4V0C combo
        if mineshaftNames.contains("Thalia") && mineshaftNames.contains("Freesia") && mineshaftNames.contains("H4V0C") {
            return "Thalia Triple Burst"
        }
        
        // Edmund warehouse burst
        if warehouseNames.contains("Mr. Edmund") {
            return "Edmund Warehouse Burst"
        }
        
        // Damian elevator rush
        if elevatorNames.contains("Damian Jones") {
            return "Damian Elevator Rush"
        }
        
        // H4V0C + Freesia
        if mineshaftNames.contains("H4V0C") && mineshaftNames.contains("Freesia") {
            return "H4V0C Multiplier Combo"
        }
        
        return "Custom Strategy"
    }
    
    private static func buildStrategySummary(
        warehouse: [RecognizedSM],
        elevator: [RecognizedSM],
        mineshaft: [RecognizedSM],
        roster: [RecognizedSM]
    ) -> String {
        var lines: [String] = []
        
        // Building assignments
        if !mineshaft.isEmpty {
            let names = mineshaft.map { $0.directoryMatch?.name ?? $0.resolvedName }.joined(separator: ", ")
            lines.append("**Mineshaft:** \(names)")
        }
        
        if !elevator.isEmpty {
            let names = elevator.map { $0.directoryMatch?.name ?? $0.resolvedName }.joined(separator: ", ")
            lines.append("**Elevator:** \(names)")
        }
        
        if !warehouse.isEmpty {
            let names = warehouse.map { $0.directoryMatch?.name ?? $0.resolvedName }.joined(separator: ", ")
            lines.append("**Warehouse:** \(names)")
        }
        
        if lines.isEmpty {
            return "No managers available. Import manager cards to generate a strategy."
        }
        
        lines.append("")
        
        // Burst macro based on lineup
        let macro = generateBurstMacro(warehouse: warehouse, elevator: elevator, mineshaft: mineshaft, roster: roster)
        lines.append(macro)
        
        return lines.joined(separator: "\n")
    }
    
    private static func generateBurstMacro(
        warehouse: [RecognizedSM],
        elevator: [RecognizedSM],
        mineshaft: [RecognizedSM],
        roster: [RecognizedSM]
    ) -> String {
        let warehouseNames = warehouse.map { $0.directoryMatch?.name ?? $0.resolvedName }
        let elevatorNames = elevator.map { $0.directoryMatch?.name ?? $0.resolvedName }
        let mineshaftNames = mineshaft.map { $0.directoryMatch?.name ?? $0.resolvedName }
        
        // Thalia + Freesia + H4V0C combo
        if mineshaftNames.contains("Thalia") && mineshaftNames.contains("Freesia") && mineshaftNames.contains("H4V0C") {
            if elevatorNames.contains("Damian Jones") && warehouseNames.contains("Mr. Edmund") {
                return """
                **Burst macro:**
                1. Open with Freesia (2m) + Thalia (5m) to load the mineshaft.
                2. When miners are walking, fire H4V0C (3m) to multiply drops.
                3. As the belt fills up, trigger Damian (5m) on Elevator.
                4. When the ramp is full, fire Edmund (2m) + optionally Luxario to keep Warehouse ahead.
                """
            } else {
                return """
                **Burst macro:**
                1. Open with Freesia (2m) + Thalia (5m) to load the mineshaft.
                2. When miners are walking, fire H4V0C (3m) to multiply drops.
                3. Use your best elevator manager when the belt fills.
                4. Use warehouse manager or cost reducers to clear the ramp.
                """
            }
        }
        
        // Edmund-focused (no top mineshaft combo)
        if warehouseNames.contains("Mr. Edmund") && !mineshaftNames.contains("H4V0C") {
            return """
            **Burst macro:**
            1. Build up resources using cost reducers (Mark/Mrs. Goodman/Goodman Jr.).
            2. When elevator is ready, trigger your best elevator speeder.
            3. As warehouse ramp fills, fire Edmund (2m) for warehouse burst.
            4. Rotate mineshaft managers for steady production.
            """
        }
        
        // H4V0C without full combo
        if mineshaftNames.contains("H4V0C") {
            return """
            **Burst macro:**
            1. Load mineshaft with available managers.
            2. Fire H4V0C (3m) when miners are walking to multiply drops.
            3. Speed elevator with available managers.
            4. Clear warehouse with cost reducers or Edmund if available.
            """
        }
        
        // Fallback for incomplete roster
        if mineshaft.isEmpty || elevator.isEmpty || warehouse.isEmpty {
            return """
            **Fallback Strategy:**
            No Thalia/Freesia/H4V0C yet – focus on cost reducers (Mark/Mrs. Goodman/Goodman Jr.) and your strongest elevator speeder (Damian/Sojo/Lee) until you unlock a main burst combo.
            """
        }
        
        // Generic strategy
        return """
        **Burst macro:**
        1. Activate mineshaft managers to load the mine.
        2. Use elevator managers when the belt fills.
        3. Clear warehouse with available managers.
        4. Repeat the cycle, timing bursts for maximum overlap.
        """
    }
    
    private static func estimateMultiplier(
        warehouse: [RecognizedSM],
        elevator: [RecognizedSM],
        mineshaft: [RecognizedSM]
    ) -> Double? {
        let allManagers = warehouse + elevator + mineshaft
        guard !allManagers.isEmpty else { return nil }
        
        let totalBoost = allManagers.reduce(0.0) { sum, sm in
            let mult = sm.directoryMatch?.active?.multiplier ?? 0.0
            return sum + mult
        }
        
        let avgBoost = totalBoost / Double(allManagers.count)
        return avgBoost > 0 ? avgBoost : nil
    }
    
    // MARK: - Helper Types
    
    private struct ScoredManager {
        let manager: RecognizedSM
        let score: Double
    }
}
