import Foundation

extension SMStats {
    public var primaryBoostDisplay: String? {
        if let multiplier = activeMultiplierDisplay {
            return multiplier
        }
        if let percent = primaryPercentDisplay {
            return percent
        }
        return nil
    }

    public var secondaryBoostDisplay: String? {
        let extras = secondaryBoostTokens
        guard !extras.isEmpty else { return nil }
        return extras.joined(separator: " • ")
    }

    public var durationDisplay: String? {
        guard !durationDisplays.isEmpty else { return nil }
        return durationDisplays.joined(separator: " • ")
    }
}
