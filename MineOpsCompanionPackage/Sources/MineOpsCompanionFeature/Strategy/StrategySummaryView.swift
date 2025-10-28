import SwiftUI
import UIKit

struct StrategySummaryView: View {
    @State private var summary: String = "No data yet."
    private let engine = StrategyEngine()

    var body: some View {
        ScrollView {
            Text(summary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Strategy Summary")
        .toolbar {
            Button("Generate") { generateMockSummary() }
        }
    }

    private func generateMockSummary() {
        let mock = [
            OCRResult(image: UIImage(), parsedName: "Mr. Edmund", parsedLevel: 10, parsedBoost: 650, parsedBoostType: "Warehouse"),
            OCRResult(image: UIImage(), parsedName: "Freesia", parsedLevel: 9, parsedBoost: 480, parsedBoostType: "Transport"),
            OCRResult(image: UIImage(), parsedName: "H4V0C", parsedLevel: 7, parsedBoost: 400, parsedBoostType: "Mine")
        ]
        summary = engine.generateSummary(for: mock)
    }
}
