import SwiftUI
import UIKit

struct StrategySummaryView: View {

    @State private var strategyText: String = "No data yet."
    @State private var burstSteps: [StrategyEngine.BurstStep] = []

    var body: some View {
        ScrollView {
            VStack(spacing: MineOpsLayout.sectionSpacing) {
                CardContainer(title: "Strategy Summary") {
                    Text(strategyText)
                        .mineOpsBody()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("strategySummaryText")
                }

                if !burstSteps.isEmpty {
                    CardContainer(title: "Burst Macro") {
                        VStack(alignment: .leading, spacing: MineOpsLayout.itemSpacing) {
                            ForEach(burstSteps) { step in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("#\(step.order) \(step.title)")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(step.managerName) • \(step.role)")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text("T+\(step.startOffsetSeconds)s for \(step.durationSeconds)s")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .accessibilityIdentifier("burstMacroSteps")
                    }
                }

                MineOpsButton(label: "Generate Strategy", icon: "wand.and.stars") {
                    generate(from: [])
                }
                .accessibilityIdentifier("generateStrategyButton")
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
                Text("Strategy Summary")
                    .font(.headline)
                    .foregroundStyle(Color.accentCyan)
            }
            ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { generate(from: []) }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityLabel("Regenerate strategy")
            }
        }
    }

    private func generate(from recognized: [RecognizedSM]) {
        let summary = StrategyEngine.generate(from: recognized)
        strategyText = summary.text
        burstSteps = summary.burstSteps
    }
}


