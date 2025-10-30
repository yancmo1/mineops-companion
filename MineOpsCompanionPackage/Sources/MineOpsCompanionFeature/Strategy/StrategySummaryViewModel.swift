import Foundation

@MainActor
public final class StrategySummaryViewModel: ObservableObject {
  @Published public var strategyText: String = "No data yet."

  public init() {}

  public func canGenerate(from recognized: [RecognizedSM]) -> Bool {
    let depts = Set(recognized.compactMap { $0.directoryMatch?.department })
    return depts.contains("mineshaft") && depts.contains("elevator") && depts.contains("warehouse")
  }

  public func generate(from recognized: [RecognizedSM]) {
    strategyText = StrategyEngine.generate(from: recognized).text
  }
}
