import Foundation

public struct SyncMetadata: Codable, Equatable {
    public var lastAttemptAt: Date?
    public var lastSuccessfulSyncAt: Date?
    public var lastGameSaveDisplay: String?
    public var playerName: String?
    public var lastGameSaveAt: Date?
    public var importedManagerCount: Int?
    public var payloadFormat: String?
    public var maskedPlayerID: String?
    public var appBuild: String?
    // Recently-updated manager ids (master.id string values) recorded after applying a sync
    public var recentlyUpdatedManagerIDs: [String]?
    // Timestamp when the recent updates were recorded
    public var recentUpdateAt: Date?

    public init() {}
}
