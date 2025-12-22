import Foundation

@MainActor
public final class StrategySummaryViewModel: ObservableObject {
  @Published public var strategyText: String = "No data yet."
  @Published public var burstSteps: [StrategyEngine.BurstStep] = []

  public init() {}

  public func canGenerate(from recognized: [RecognizedSM]) -> Bool {
    let depts = Set(recognized.compactMap { $0.directoryMatch?.department })
    return depts.contains("mineshaft") && depts.contains("elevator") && depts.contains("warehouse")
  }

  public func generate(from recognized: [RecognizedSM]) {
    let summary = StrategyEngine.generate(from: recognized)
    strategyText = summary.text
    burstSteps = summary.burstSteps
  }
}
