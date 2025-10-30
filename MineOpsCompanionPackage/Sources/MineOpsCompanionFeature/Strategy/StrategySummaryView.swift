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
                            .foregroundStyle(.secondary)
                    }
                }

                CardContainer(title: "Strategy Summary") {
                    Text(viewModel.strategyText)
                        .mineOpsBody()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("strategySummaryText")
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


