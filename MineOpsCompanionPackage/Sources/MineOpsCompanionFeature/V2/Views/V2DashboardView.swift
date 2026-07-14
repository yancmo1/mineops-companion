import SwiftUI

struct V2DashboardView: View {
    @Environment(SMProgressService.self) private var progressService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MineOpsLayout.sectionSpacing) {
                    // Overview
                    overviewCards

                    // Coverage by area
                    areaCoverage

                    // Top unlocked SMs
                    topManagersSection

                    // Sync info
                    syncInfoCard
                }
                .padding(MineOpsLayout.cardPadding)
            }
            .background(Color.mineDark.ignoresSafeArea())
            .navigationTitle("MineOps")
            .navigationBarTitleDisplayMode(.large)
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

    private var topManagersSection: some View {
        CardContainer(title: "Top Unlocked") {
            let top = progressService.progress
                .filter(\.unlocked)
                .sorted { $0.master.rarityPriority < $1.master.rarityPriority }
                .prefix(8)

            if top.isEmpty {
                Text("Sync game data to see your managers.")
                    .mineOpsCaption()
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(top)) { sm in
                        NavigationLink(destination: V2ManagerDetailView(sm: sm)) {
                            HStack {
                                Text(sm.master.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text("Lv\(sm.level)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color.mineDarkLight.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var syncInfoCard: some View {
        CardContainer(title: "Sync") {
            VStack(spacing: 8) {
                Text("Manager data is pulled from Knight's Hub (idle-miners.com) on launch.")
                    .mineOpsCaption()
                    .foregroundStyle(.secondary)

                Text("Game progress is synced via the Sync tab using Kolibri API.")
                    .mineOpsCaption()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func areaColor(_ dept: SMDepartment) -> Color {
        switch dept {
        case .mineshaft: return .accentOrange
        case .elevator: return .accentCyan
        case .warehouse: return .purple
        }
    }
}

extension SMMasterEntry {
    fileprivate var rarityPriority: Int {
        switch rarity.lowercased() {
        case "legendary": return 0
        case "epic": return 1
        case "rare": return 2
        case "common": return 3
        default: return 4
        }
    }
}
