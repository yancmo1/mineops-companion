import SwiftUI

/// Sheet view that loads and displays SM upgrade projection from JSON database
struct SMUpgradeProjectionSheet: View {
    let managerId: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var manager: SMBaseStatsLoader.Manager?
    @State private var loadError: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if let manager = manager {
                    if let (rarity, baseMultiplier, passives) = SMBaseStatsLoader.toCalculatorInputs(manager: manager) {
                        SMUpgradeProjectionView(
                            managerName: manager.name,
                            rarity: rarity,
                            baseActiveMultiplier: baseMultiplier,
                            passives: passives.map { passive in
                                let description = manager.passives.first { $0.type == passive.type }?.description ?? passive.type
                                return (passive.unlockLevel, passive.baseMultiplier, passive.type, description)
                            }
                        )
                    } else {
                        Text("Could not load upgrade data for this manager")
                            .foregroundStyle(.secondary)
                    }
                } else if let loadError = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("Error Loading Manager")
                            .font(.headline)
                        Text(loadError)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle("Upgrade Projection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadManager()
        }
    }
    
    @MainActor
    private func loadManager() async {
        do {
            manager = try SMBaseStatsLoader.getManager(id: managerId)
            if manager == nil {
                loadError = "Manager '\(managerId)' not found in database"
            }
        } catch {
            loadError = "Failed to load manager data: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    SMUpgradeProjectionSheet(managerId: "chester")
}
