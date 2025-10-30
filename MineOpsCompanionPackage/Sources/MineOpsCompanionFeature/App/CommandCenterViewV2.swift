import SwiftUI

struct CommandCenterViewV2: View {
    @EnvironmentObject private var review: OCRReviewViewModel

    @State private var navigateToImport = false
    @State private var navigateToStrategy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MineOpsLayout.sectionSpacing) {
                    ocrSection
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
                    Image(systemName: "gearshape.2.fill")
                        .foregroundStyle(Color.accentCyan)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .principal) {
                    Text("MineOps Dashboard")
                        .font(.headline)
                        .foregroundStyle(Color.accentCyan)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { navigateToImport = true }) {
                        Image(systemName: "photo.on.rectangle")
                    }
                    .accessibilityLabel("Open OCR import")
                }
            }
            .tint(.accentCyan)
            .navigationDestination(isPresented: $navigateToImport) {
                OCRReviewView()
            }
            .navigationDestination(isPresented: $navigateToStrategy) {
                StrategySummaryView()
            }
        }
    }

    private var ocrSection: some View {
        CardContainer(title: "OCR Import") {
            VStack(spacing: 16) {
                Text("Recognized \(recognizedCount) super managers across \(coveredDepartments) department(s).")
                    .mineOpsBody()
                MineOpsButton(label: "Import Screenshots", icon: "photo.on.rectangle") {
                    navigateToImport = true
                }
                ProgressView(value: importProgressValue)
                    .tint(.accentCyan)
                Text("Coverage \(Int(importProgressValue * 100))% of departments")
                    .mineOpsCaption()
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
            QuickStat(title: "Recognized", value: "\(recognizedCount)", color: .accentCyan)
            QuickStat(title: "Depts Covered", value: "\(coveredDepartments)/3", color: .accentOrange)
            QuickStat(title: "Needs Review", value: "\(needsReviewCount)", color: .pink)
        }
    }
}

#Preview("Command Center V2") {
    CommandCenterViewV2()
        .environmentObject(OCRReviewViewModel())
        .preferredColorScheme(.dark)
}

private extension CommandCenterViewV2 {
    struct DepartmentSummary {
        let label: String
        let percent: Double
        let color: Color
    }

    var recognizedCount: Int { review.recognized.count }

    var coveredDepartments: Int {
        Set(review.recognized.compactMap { canonicalDepartment(for: $0) }).count
    }

    var needsReviewCount: Int {
        review.recognized.filter { !$0.stats.hasAnyStats }.count
    }

    var departmentSummaries: [DepartmentSummary] {
        let mappings: [(label: String, key: String, color: Color)] = [
            ("Mine", "mineshaft", .accentOrange),
            ("Transport", "elevator", .accentCyan),
            ("Warehouse", "warehouse", .purple)
        ]

        return mappings.map { item in
            let entries = review.recognized.filter { canonicalDepartment(for: $0) == item.key }
            let multipliers = entries.map { $0.primaryBoostScore }.filter { $0 > 0 }
            let averageMultiplier = multipliers.isEmpty ? 1 : multipliers.reduce(0, +) / Double(multipliers.count)
            let percent = max((averageMultiplier - 1) * 100, 0)
            return DepartmentSummary(label: item.label, percent: percent, color: item.color)
        }
    }

    var averageBoostPercent: Double {
        let percents: [Double] = review.recognized.compactMap { sm in
            if let value = sm.active.multiplier {
                return (value - 1) * 100
            }
            if let value = sm.stats.percentNumberValues.first {
                return value
            }
            if let multiplier = sm.stats.multipliersDescending.first?.value {
                return (multiplier - 1) * 100
            }
            if let multiplier = sm.directoryMatch?.active?.multiplier {
                return (multiplier - 1) * 100
            }
            return nil
        }
        guard !percents.isEmpty else { return 0 }
        let total = percents.reduce(0, +)
        return total / Double(percents.count)
    }

    var averageBoostDisplay: String {
        averageBoostPercent <= 0 ? "—" : "\(Int(averageBoostPercent.rounded()))%"
    }

    var averageBoostProgress: Double {
        guard averageBoostPercent > 0 else { return 0 }
        return min(averageBoostPercent / 1000, 1)
    }

    var nextDueMinutes: Int? {
        review.recognized
            .compactMap {
                if let seconds = $0.active.durationSeconds { return seconds / 60 }
                return $0.stats.minuteDurations.min()
            }
            .min()
    }

    var nextDueDisplay: String {
        guard let minutes = nextDueMinutes else { return "—" }
        if minutes >= 60 {
            let hours = Double(minutes) / 60
            return String(format: "%.1fh", hours)
        } else {
            return "\(minutes)m"
        }
    }

    var nextDueProgress: Double {
        guard let minutes = nextDueMinutes else { return 0 }
        return min(Double(minutes) / 180, 1)
    }

    var importProgressValue: Double {
        guard coveredDepartments > 0 else { return 0 }
        return min(Double(coveredDepartments) / 3, 1)
    }

    func canonicalDepartment(for sm: RecognizedSM) -> String? {
        if let role = sm.role?.lowercased() {
            switch role {
            case "mine", "mineshaft": return "mineshaft"
            case "elevator": return "elevator"
            case "warehouse": return "warehouse"
            case "transport": return "elevator"
            default: break
            }
        }
        return sm.directoryMatch?.department
    }
}
