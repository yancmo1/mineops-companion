import SwiftUI
import UIKit

struct StrategySummaryView: View {
    @EnvironmentObject private var review: OCRReviewViewModel
    @StateObject private var viewModel = StrategySummaryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: MineOpsLayout.sectionSpacing) {
                if review.recognized.isEmpty {
                    CardContainer {
                        Text("Import manager cards first to generate a plan.")
                            .mineOpsBody()
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                CardContainer(title: "Strategy Summary") {
                    Text(viewModel.strategyText)
                        .mineOpsBody()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("strategySummaryText")
                }

                if !viewModel.burstSteps.isEmpty {
                    CardContainer(title: "Burst Macro") {
                        VStack(alignment: .leading, spacing: MineOpsLayout.itemSpacing) {
                            ForEach(viewModel.burstSteps) { step in
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
                    viewModel.generate(from: review.recognized)
                }
                .disabled(!viewModel.canGenerate(from: review.recognized))
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
                Button(action: { viewModel.generate(from: review.recognized) }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .disabled(!viewModel.canGenerate(from: review.recognized))
                .accessibilityLabel("Regenerate strategy")
            }
        }
    }
}


