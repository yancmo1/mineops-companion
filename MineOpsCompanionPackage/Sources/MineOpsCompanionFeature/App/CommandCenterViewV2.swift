import SwiftUI

struct CommandCenterViewV2: View {
    @State private var navigateToStrategy = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MineOpsLayout.sectionSpacing) {
                    summarySection
                    strategySection
                    quickStats
                }
                .padding(MineOpsLayout.cardPadding)
            }
            .background(Color.mineDark.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.2.fill")
                            .foregroundStyle(Color.accentCyan)
                    }
                    .accessibilityLabel("Open settings")
                    .accessibilityIdentifier("openSettingsButton")
                }
                ToolbarItem(placement: .principal) {
                    Text("MineOps Dashboard")
                        .font(.headline)
                        .foregroundStyle(Color.accentCyan)
                }
            }
            .tint(.accentCyan)
            .navigationDestination(isPresented: $navigateToStrategy) {
                StrategyPipelineView()
            }
            .sheet(isPresented: $showingSettings) {
                MineOpsSettingsView()
            }
        }
    }

    private var summarySection: some View {
        CardContainer(title: "Super Managers Overview") {
            VStack(spacing: 18) {
                ForEach(departmentSummaries, id: \.label) { summary in
                    BoostBar(
                        label: summary.label,
                        boostValue: summary.percent,
                        color: summary.color,
                        maxValue: 1500
                    )
                }
            }
        }
    }

    private var strategySection: some View {
        CardContainer(title: "Readiness Snapshot") {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    StatGauge(
                        label: "Total SMs",
                        value: "\(recognizedCount)",
                        progress: min(Double(recognizedCount) / 30, 1),
                        color: .accentCyan
                    )
                    StatGauge(
                        label: "Avg Boost",
                        value: averageBoostDisplay,
                        progress: averageBoostProgress,
                        color: .accentOrange
                    )
                    StatGauge(
                        label: "Next Due",
                        value: nextDueDisplay,
                        progress: nextDueProgress,
                        color: .pink
                    )
                }
                .frame(maxWidth: .infinity)

                MineOpsButton(label: "Generate Strategy", icon: "wand.and.stars") {
                    navigateToStrategy = true
                }
            }
        }
    }

    private var quickStats: some View {
        HStack(spacing: 12) {
            QuickStat(title: "Total SMs", value: "\(recognizedCount)", color: .accentCyan)
            QuickStat(title: "Depts Covered", value: "\(coveredDepartments)/3", color: .accentOrange)
        }
    }
}

#Preview("Command Center V2") {
    CommandCenterViewV2()
        .preferredColorScheme(.dark)
}

private extension CommandCenterViewV2 {
    struct DepartmentSummary {
        let label: String
        let percent: Double
        let color: Color
    }

    var recognizedCount: Int { 0 }

    var coveredDepartments: Int { 0 }

    var departmentSummaries: [DepartmentSummary] {
        let mappings: [(label: String, key: String, color: Color)] = [
            ("Mine", "mineshaft", .accentOrange),
            ("Transport", "elevator", .accentCyan),
            ("Warehouse", "warehouse", .purple)
        ]

        return mappings.map { item in
            DepartmentSummary(label: item.label, percent: 0, color: item.color)
        }
    }

    var averageBoostPercent: Double { 0 }

    var averageBoostDisplay: String { "—" }

    var averageBoostProgress: Double { 0 }

    var nextDueMinutes: Int? { nil }

    var nextDueDisplay: String { "—" }

    var nextDueProgress: Double { 0 }
}
