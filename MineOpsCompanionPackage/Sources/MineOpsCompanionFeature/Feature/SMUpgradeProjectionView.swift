import SwiftUI

/// View to show projected upgrade stats for a Super Manager
struct SMUpgradeProjectionView: View {
    let managerName: String
    let rarity: SMUpgradeCalculator.Rarity
    let baseActiveMultiplier: Double
    let passives: [(unlockLevel: Int, baseMultiplier: Double, type: String, description: String)]
    
    @State private var selectedLevel: Int = 1
    @State private var selectedPromotion: Int = 0
    
    private var calculatedStats: SMCalculatedStats {
        SMUpgradeCalculator.calculateStats(
            baseActiveMultiplier: baseActiveMultiplier,
            currentLevel: selectedLevel,
            promotion: selectedPromotion,
            rarity: rarity,
            passives: passives.map { ($0.unlockLevel, $0.baseMultiplier, $0.type) }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("\(managerName) Upgrade Projection")
                .font(.title2)
                .bold()
            
            Text(rarity.rawValue)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
            
            // Level Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Level: \(selectedLevel)/\(rarity.maxLevel)")
                    .font(.headline)
                
                Slider(value: Binding(
                    get: { Double(selectedLevel) },
                    set: { selectedLevel = Int($0) }
                ), in: 1...Double(rarity.maxLevel), step: 1)
                .tint(.blue)
            }
            .padding(.vertical, 8)
            
            // Promotion Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Promotion: \(selectedPromotion)/\(rarity.maxPromotion)")
                    .font(.headline)
                
                Slider(value: Binding(
                    get: { Double(selectedPromotion) },
                    set: { selectedPromotion = Int($0) }
                ), in: 0...Double(rarity.maxPromotion), step: 1)
                .tint(.green)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Active Ability
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Ability")
                    .font(.headline)
                
                HStack {
                    Text("Multiplier:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(calculatedStats.activeMultiplierDisplay)
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Passive Abilities
            if !calculatedStats.passives.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passive Abilities")
                        .font(.headline)
                    
                    ForEach(Array(calculatedStats.passives.enumerated()), id: \.offset) { index, passive in
                        if let passiveInfo = passives.first(where: { $0.type == passive.type }) {
                            PassiveStatRow(
                                description: passiveInfo.description,
                                multiplier: passive.multiplierDisplay,
                                unlockLevel: passive.unlockLevel
                            )
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passive Abilities")
                        .font(.headline)
                    
                    Text("No passives unlocked at this level")
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding()
                }
            }
            
            // Unlock Preview
            if selectedLevel < rarity.maxLevel {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next Unlocks")
                        .font(.headline)
                    
                    ForEach(passives.filter { $0.unlockLevel > selectedLevel }.prefix(3), id: \.unlockLevel) { passive in
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.orange)
                            Text("Level \(passive.unlockLevel):")
                                .foregroundStyle(.secondary)
                            Text(passive.description)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
        }
        .padding()
    }
}

/// Row displaying a single passive stat
private struct PassiveStatRow: View {
    let description: String
    let multiplier: String
    let unlockLevel: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(description)
                    .font(.body)
                Text("Unlocked at level \(unlockLevel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(multiplier)
                .font(.title3)
                .bold()
                .foregroundStyle(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview("Chester - Common") {
    SMUpgradeProjectionView(
        managerName: "Chester",
        rarity: .common,
        baseActiveMultiplier: 5.0,
        passives: [
            (unlockLevel: 10, baseMultiplier: 0.5, type: "upgrade_cost_reduction", description: "Upgrade Cost Reduction")
        ]
    )
}

#Preview("Sir Lorenzo - Legendary") {
    SMUpgradeProjectionView(
        managerName: "Sir Lorenzo",
        rarity: .legendary,
        baseActiveMultiplier: 10.19,
        passives: [
            (unlockLevel: 10, baseMultiplier: 4.17, type: "mining_speed", description: "Mining Speed Boost"),
            (unlockLevel: 30, baseMultiplier: 0.5, type: "upgrade_cost_reduction", description: "Upgrade Cost Reduction"),
            (unlockLevel: 50, baseMultiplier: 1.41, type: "continent_income", description: "Continent Income Boost")
        ]
    )
}
