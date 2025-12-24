import Foundation

@MainActor
@available(*, deprecated, message: "Prefer MV: derive strategy summary directly in StrategySummaryView using StrategyEngine.")
final class StrategySummaryViewModel: ObservableObject {
  @Published var strategyText: String = "No data yet."
  @Published var burstSteps: [StrategyEngine.BurstStep] = []

  init() {}

  func canGenerate(from recognized: [RecognizedSM]) -> Bool {
    let depts = Set(recognized.compactMap { $0.directoryMatch?.department })
    return depts.contains("mineshaft") && depts.contains("elevator") && depts.contains("warehouse")
  }

  func generate(from recognized: [RecognizedSM]) {
    let summary = StrategyEngine.generate(from: recognized)
    strategyText = summary.text
    burstSteps = summary.burstSteps
  }
}
