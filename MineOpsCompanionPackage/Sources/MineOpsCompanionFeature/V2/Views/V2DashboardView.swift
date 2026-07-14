import SwiftUI

struct V2DashboardView: View {
    @Environment(SMProgressService.self) private var progressService
    @State private var syncService = KolibriSyncService.shared
    @Binding private var selectedTab: V2RootTab

    private let metadataStore = SyncMetadataStore.shared

    init(selectedTab: Binding<V2RootTab>) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MineOpsLayout.sectionSpacing) {
                    syncStatusHeader
                    strongestByAreaSection
                    upgradeOpportunitiesSection
                    quickActionsSection
                    collectionSection
                    areaCoverage
                }
                .padding(MineOpsLayout.cardPadding)
            }
            .background(Color.mineDark.ignoresSafeArea())
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var collectionSection: some View {
        CardContainer(title: "Collection") {
            overviewCards
        }
    }

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("Total SMs", "\(progressService.totalCount)", color: .accentCyan)
            statCard("Unlocked", "\(progressService.unlockedCount)", color: .green)
            statCard("Locked", "\(progressService.totalCount - progressService.unlockedCount)", color: .secondary)
        }
    }

    private func statCard(_ title: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.mineDarkLight.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var areaCoverage: some View {
        CardContainer(title: "Coverage by Area") {
            ForEach(SMDepartment.allCases, id: \.self) { dept in
                let unlocked = progressService.coverageByArea[dept] ?? 0
                let total = progressService.totalByArea[dept] ?? 0
                let progress = total > 0 ? Double(unlocked) / Double(total) : 0

                HStack {
                    Text(dept.displayName)
                        .mineOpsBody()
                    Spacer()
                    Text("\(unlocked)/\(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .tint(areaColor(dept))
            }
        }
    }

    private var syncStatusHeader: some View {
        CardContainer(title: "Sync Status") {
            switch syncService.syncState {
            case .syncing:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Syncing game data…")
                        .mineOpsBody()
                    ProgressView()
                }

            case .error:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Couldn’t refresh game data")
                        .mineOpsBody()
                    if let lastSuccess = metadataStore.metadata.lastSuccessfulSyncAt {
                        Text("Showing your last successful sync from \(relative(lastSuccess)).")
                            .mineOpsCaption()
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No previous sync found yet.")
                            .mineOpsCaption()
                            .foregroundStyle(.secondary)
                    }
                    MineOpsButton(label: "Try Again", icon: "arrow.clockwise") {
                        Task { await syncService.syncAndApplyToProgress() }
                    }
                }

            case .idle, .success:
                if !syncService.hasUsableCredentials {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect Idle Miner to load your Super Managers")
                            .mineOpsBody()
                        MineOpsButton(label: "Connect Game", icon: "link") {
                            selectedTab = .more
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if let playerName = metadataStore.metadata.playerName, !playerName.isEmpty {
                            Text(playerName)
                                .font(.headline)
                        } else {
                            Text("Connected")
                                .font(.headline)
                        }

                        if let lastSuccess = metadataStore.metadata.lastSuccessfulSyncAt {
                            Text("Synced \(relative(lastSuccess))")
                                .mineOpsCaption()
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not synced yet")
                                .mineOpsCaption()
                                .foregroundStyle(.secondary)
                        }

                        if let gameSave = metadataStore.metadata.lastGameSaveAt {
                            Text("Game save: \(relative(gameSave))")
                                .mineOpsCaption()
                                .foregroundStyle(.secondary)
                        }

                        Text("\(progressService.unlockedCount) managers unlocked")
                            .mineOpsCaption()
                            .foregroundStyle(.secondary)

                        MineOpsButton(label: "Sync Now", icon: "arrow.clockwise") {
                            Task { await syncService.syncAndApplyToProgress() }
                        }
                    }
                }
            }
        }
    }

    private var strongestByAreaSection: some View {
        CardContainer(title: "Strongest by Area") {
            VStack(spacing: 8) {
                strongestRow(for: .mineshaft)
                strongestRow(for: .elevator)
                strongestRow(for: .warehouse)
            }
        }
    }

    @ViewBuilder
    private func strongestRow(for dept: SMDepartment) -> some View {
        if let strongest = progressService.strongestUnlockedManager(in: dept) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dept.displayName)
                        .font(.caption)
                        .foregroundStyle(areaColor(dept))
                    Text(strongest.master.name)
                        .font(.subheadline.bold())
                    Text("Lv\(strongest.level) • R\(strongest.rank) • P\(strongest.promoted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.0f", strongest.effectiveActiveValue(using: SMMasterDataService.shared.activeScaling)))
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentCyan)
            }
        } else {
            HStack {
                Text(dept.displayName)
                    .font(.caption)
                    .foregroundStyle(areaColor(dept))
                Spacer()
                Text("No unlocked manager yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var upgradeOpportunitiesSection: some View {
        CardContainer(title: "Ready to Improve") {
            let opportunities = progressService.upgradeOpportunityManagers(limit: 4)
            if opportunities.isEmpty {
                Text("No fragment-backed upgrade opportunities yet.")
                    .mineOpsCaption()
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(opportunities) { manager in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(manager.master.name)
                                    .font(.subheadline)
                                Text("\(manager.fragments) fragments available")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Lv\(manager.level)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var quickActionsSection: some View {
        CardContainer(title: "Quick Actions") {
            VStack(spacing: 8) {
                MineOpsButton(label: "Sync Now", icon: "arrow.clockwise") {
                    Task { await syncService.syncAndApplyToProgress() }
                }
                HStack(spacing: 8) {
                    MineOpsButton(label: "View Managers", icon: "person.text.rectangle") {
                        selectedTab = .managers
                    }
                    MineOpsButton(label: "Build Strategy", icon: "wand.and.stars") {
                        selectedTab = .strategy
                    }
                }
            }
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func areaColor(_ dept: SMDepartment) -> Color {
        switch dept {
        case .mineshaft: return .accentOrange
        case .elevator: return .accentCyan
        case .warehouse: return .purple
        }
    }
}
