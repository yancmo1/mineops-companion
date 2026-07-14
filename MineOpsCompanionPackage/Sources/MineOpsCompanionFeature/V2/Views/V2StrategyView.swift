import SwiftUI

struct V2StrategyView: View {
    @Environment(SMProgressService.self) private var progressService
    @State private var strategyService = V2StrategyService.shared
    @State private var config = AIProviderConfig.shared
    @State private var syncService = KolibriSyncService.shared
    @State private var metadataStore = SyncMetadataStore.shared

    // Mine context
    @State private var selectedMineType: MineType = MineSettingsStore.shared.selectedMineType
    @State private var mineNumber: Int = MineSettingsStore.shared.mineNumber(for: MineSettingsStore.shared.selectedMineType)
    @State private var selectedContinentMine: ContinentMine = .ruby
    @State private var prestige: Int = 0
    @State private var maxShaft: Int = 30

    @State private var editingNumber: EditingNumber?

    private let settingsStore = MineSettingsStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MineOpsLayout.sectionSpacing) {
                    strategyFreshnessCard

                    // Provider info
                    CardContainer(title: "AI Provider") {
                        HStack {
                            Image(systemName: config.activeProvider == .openAI ? "brain" : "sparkle.magnifyingglass")
                                .foregroundStyle(Color.accentCyan)
                            Text(config.activeProvider.displayName)
                                .mineOpsBody()
                            Spacer()
                            if !config.hasKey(for: config.activeProvider) {
                                Text("No key set")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    // Mine details
                    mineDetailsSection

                    // Run strategy
                    MineOpsButton(
                        label: strategyService.isAnalyzing
                            ? "Analyzing…"
                            : "Generate Strategy (\(config.activeProvider.displayName))",
                        icon: strategyService.isAnalyzing ? "ellipsis.circle" : "wand.and.stars"
                    ) {
                        Task { await generateStrategy() }
                    }
                    .disabled(strategyService.isAnalyzing || !config.hasKey(for: config.activeProvider))
                    .accessibilityIdentifier("runStrategyButton")

                    // Error
                    if let error = strategyService.lastError {
                        CardContainer(title: "Error", titleColor: .red) {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    // Result
                    if let output = strategyService.lastOutput {
                        strategyResultView(output)
                    }

                    // Management summary
                    managerOverview
                }
                .padding(MineOpsLayout.cardPadding)
            }
            .background(Color.mineDark.ignoresSafeArea())
            .navigationTitle("Strategy")
        }
    }

    private var strategyFreshnessCard: some View {
        CardContainer(title: "Roster Freshness") {
            VStack(alignment: .leading, spacing: 8) {
                if let syncedAt = metadataStore.metadata.lastSuccessfulSyncAt {
                    HStack(spacing: 4) {
                        Text("Using roster synced")
                            .mineOpsBody()
                        Text(syncedAt, style: .relative)
                            .mineOpsBody()
                        Text("ago")
                            .mineOpsBody()
                    }
                } else {
                    Text("Sync your game before building a strategy.")
                        .mineOpsBody()
                        .foregroundStyle(.orange)
                }

                if syncService.syncState == .syncing {
                    Text("Syncing game data…")
                        .mineOpsCaption()
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await syncService.syncAndApplyToProgress() }
                } label: {
                    Label(syncService.syncState == .syncing ? "Syncing…" : "Sync Now", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(syncService.syncState == .syncing)
            }
        }
    }

    private var mineDetailsSection: some View {
        CardContainer(title: "Mine Details") {
            VStack(alignment: .leading, spacing: 12) {
                // Type
                HStack {
                    Text("Type")
                        .mineOpsBody()
                    Spacer()
                    Picker("Type", selection: $selectedMineType) {
                        ForEach(MineType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.accentCyan)
                }

                if selectedMineType.usesNumberedProgression {
                    stepperRow("Mine #", value: $mineNumber, range: 1...999)
                }

                if let mines = selectedMineType.continentMines {
                    HStack {
                        Text("Mine")
                            .mineOpsBody()
                        Spacer()
                        Picker("Mine", selection: $selectedContinentMine) {
                            ForEach(mines) { mine in
                                Text(mine.rawValue).tag(mine)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.accentCyan)
                    }
                }

                stepperRow("Prestige", value: $prestige, range: 0...999)
                stepperRow("Max Shaft", value: $maxShaft, range: 1...999)
            }
        }
    }

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .mineOpsBody()
            Spacer()
            HStack(spacing: 8) {
                Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Color.accentCyan)
                }
                Text("\(value.wrappedValue)")
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 40)
                Button { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentCyan)
                }
            }
        }
    }

    private func strategyResultView(_ output: AIStrategyOutput) -> some View {
        CardContainer(title: output.comboName, titleColor: .accentCyan) {
            VStack(alignment: .leading, spacing: 12) {
                Text(output.strategySummary)
                    .mineOpsBody()
                    .foregroundStyle(.white.opacity(0.8))

                if !output.recommendedManagerIDs.isEmpty {
                    Divider()
                        .background(.white.opacity(0.2))

                    Text("Recommended Managers")
                        .font(.subheadline.bold())

                    ForEach(output.recommendedManagerIDs, id: \.self) { id in
                        if let sm = progressService.progress.first(where: { $0.id == id }) {
                            HStack {
                                Text(sm.master.name)
                                    .mineOpsBody()
                                Spacer()
                                Text(sm.master.rarity.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(rarityColor(sm.master.rarity))
                                Text("Lv\(sm.level)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let mult = output.estimatedMultiplier {
                    Divider()
                        .background(.white.opacity(0.2))

                    Text(String(format: "Estimated Boost: %.2fx", mult))
                        .font(.subheadline)
                        .foregroundStyle(Color.accentCyan)
                }
            }
        }
    }

    private var managerOverview: some View {
        CardContainer(title: "Available Managers") {
            let unlocked = progressService.progress.filter(\.unlocked)

            if unlocked.isEmpty {
                Text("Sync game data first to see your managers.")
                    .mineOpsCaption()
                    .foregroundStyle(.secondary)
            } else {
                ForEach(SMDepartment.allCases, id: \.self) { dept in
                    let count = progressService.unlockedManagers(for: dept).count
                    HStack {
                        Text(dept.displayName)
                            .mineOpsBody()
                        Spacer()
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @MainActor
    private func generateStrategy() async {
        let unlocked = progressService.progress.filter(\.unlocked)

        let input = AIStrategyPromptInput(
            availableManagers: unlocked,
            mineType: selectedMineType.rawValue,
            mineNumber: selectedMineType.usesNumberedProgression ? mineNumber : nil,
            mineName: selectedMineType.continentMines != nil ? selectedContinentMine.rawValue : nil,
            prestige: prestige,
            maxShaft: maxShaft
        )

        await strategyService.generateStrategy(input: input)
    }

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "common": return .gray
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .secondary
        }
    }

    private enum EditingNumber: Identifiable {
        case mineNumber, prestige, maxShaft
        var id: String { String(describing: self) }
    }
}
