import Foundation

@MainActor
public final class StrategySummaryViewModel: ObservableObject {
  @Published public var strategyText: String = "No data yet."

  public init() {}

  public func generate(from recognized: [RecognizedSM]) {
    strategyText = StrategyEngine.generate(from: recognized).text
  }
}
