import Foundation

public enum SyncFrequency: String, CaseIterable, Codable, Identifiable, Sendable {
    case off
    case hourly
    case sixHours
    case twelveHours
    case daily

    public var id: String { rawValue }

    public var interval: TimeInterval? {
        switch self {
        case .off: return nil
        case .hourly: return 60 * 60
        case .sixHours: return 6 * 60 * 60
        case .twelveHours: return 12 * 60 * 60
        case .daily: return 24 * 60 * 60
        }
    }

    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .hourly: return "Every 1 Hour"
        case .sixHours: return "Every 6 Hours"
        case .twelveHours: return "Every 12 Hours"
        case .daily: return "Every 24 Hours"
        }
    }

    public func isDue(lastSuccessfulSyncAt: Date?, now: Date = Date()) -> Bool {
        guard let interval else {
            return false
        }
        guard let lastSuccessfulSyncAt else {
            return true
        }
        return now.timeIntervalSince(lastSuccessfulSyncAt) >= interval
    }
}
