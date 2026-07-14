@testable import MineOpsCompanionFeature
import Foundation
import Testing

@MainActor
@Suite("Sync Metadata Store")
struct SyncMetadataStoreTests {
    private let storageKey = "com.yancmo1.mineops.syncMetadata"

    @Test("Successful sync metadata is persisted")
    func successfulSyncMetadataPersists() throws {
        UserDefaults.standard.removeObject(forKey: storageKey)

        let saveDate = Date(timeIntervalSince1970: 1_700_000_000)
        SyncMetadataStore.shared.recordSuccess(
            playerName: "Diggin Dad",
            lastGameSaveAt: saveDate,
            importedManagerCount: 60,
            maskedPlayerID: "••••• 3c4",
            payloadFormat: "u58u-base64-gzip",
            appBuild: "1.2.3 (45)"
        )

        let raw = try #require(UserDefaults.standard.data(forKey: storageKey))
        let decoded = try JSONDecoder().decode(SyncMetadata.self, from: raw)

        #expect(decoded.playerName == "Diggin Dad")
        #expect(decoded.lastGameSaveAt == saveDate)
        #expect(decoded.importedManagerCount == 60)
        #expect(decoded.maskedPlayerID == "••••• 3c4")
        #expect(decoded.payloadFormat == "u58u-base64-gzip")
        #expect(decoded.appBuild == "1.2.3 (45)")
    }

    @Test("Failed attempt preserves previous success timestamp")
    func failedAttemptPreservesSuccessTimestamp() {
        UserDefaults.standard.removeObject(forKey: storageKey)

        SyncMetadataStore.shared.recordSuccess(
            playerName: "Player",
            lastGameSaveAt: Date(),
            importedManagerCount: 10,
            maskedPlayerID: "••••• abc"
        )

        let initialSuccess = SyncMetadataStore.shared.metadata.lastSuccessfulSyncAt
        #expect(initialSuccess != nil)

        SyncMetadataStore.shared.recordAttempt()

        #expect(SyncMetadataStore.shared.metadata.lastAttemptAt != nil)
        #expect(SyncMetadataStore.shared.metadata.lastSuccessfulSyncAt == initialSuccess)
    }

    @Test("Masked ID is persisted without requiring full UUID")
    func maskedIDOnly() {
        UserDefaults.standard.removeObject(forKey: storageKey)

        SyncMetadataStore.shared.recordSuccess(
            playerName: "Player",
            lastGameSaveAt: Date(),
            importedManagerCount: 12,
            maskedPlayerID: "••••• 3c4"
        )

        let stored = SyncMetadataStore.shared.metadata.maskedPlayerID
        #expect(stored == "••••• 3c4")
        #expect(stored?.contains("-") == false)
    }
}
