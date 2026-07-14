import Foundation

@MainActor
public final class SyncMetadataStore {
    public static let shared = SyncMetadataStore()

    private let key = "com.yancmo1.mineops.syncMetadata"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public private(set) var metadata: SyncMetadata = SyncMetadata()

    private init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? decoder.decode(SyncMetadata.self, from: data) else { return }
        metadata = decoded
    }

    private func save() {
        guard let data = try? encoder.encode(metadata) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    public func recordAttempt() {
        metadata.lastAttemptAt = Date()
        save()
    }

    public func recordSuccess(
        playerName: String?,
        lastGameSaveAt: Date?,
        importedManagerCount: Int?,
        maskedPlayerID: String?,
        payloadFormat: String? = nil,
        appBuild: String? = nil
    ) {
        metadata.lastSuccessfulSyncAt = Date()
        metadata.playerName = playerName
        metadata.lastGameSaveAt = lastGameSaveAt
        metadata.lastGameSaveDisplay = lastGameSaveAt.map(Self.displayFormatter.string(from:))
        metadata.importedManagerCount = importedManagerCount
        metadata.maskedPlayerID = maskedPlayerID
        metadata.payloadFormat = payloadFormat
        metadata.appBuild = appBuild ?? Self.currentAppBuild()
        save()
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static func currentAppBuild() -> String? {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (short?.isEmpty == false ? short : nil, build?.isEmpty == false ? build : nil) {
        case let (version?, number?):
            return "\(version) (\(number))"
        case let (version?, nil):
            return version
        case let (nil, number?):
            return number
        default:
            return nil
        }
    }
}
