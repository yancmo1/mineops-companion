import Foundation

final class StrategyEngine {
    func generateSummary(for managers: [OCRResult]) -> String {
        let top = managers.sorted { $0.parsedBoost > $1.parsedBoost }.prefix(5)
        var summary = "Top Super Managers by Boost:\n"
        for sm in top {
            summary += "- \(sm.parsedName): +\(Int(sm.parsedBoost))% \(sm.parsedBoostType)\n"
        }
        return summary
    }
}
