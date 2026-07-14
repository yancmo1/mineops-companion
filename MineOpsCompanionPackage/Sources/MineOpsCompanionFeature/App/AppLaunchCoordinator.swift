import Foundation

@MainActor
@Observable
final class AppLaunchCoordinator {
    static let shared = AppLaunchCoordinator()

    private(set) var hasInitialized = false
    private(set) var isLaunching = false

    let progressService = SMProgressService.shared
    let syncService = KolibriSyncService.shared

    private init() {}

    func initialize() async {
        guard !hasInitialized, !isLaunching else { return }
        isLaunching = true
        defer {
            isLaunching = false
            hasInitialized = true
        }

        await progressService.initialize()

        guard syncService.hasUsableCredentials else { return }

        // Always allow one sync on launch when frequency is Off.
        // For scheduled frequencies, sync only when due based on the last successful sync timestamp.
        let frequency = syncService.syncFrequency
        let lastSuccessfulSync = SyncMetadataStore.shared.metadata.lastSuccessfulSyncAt
        if frequency != .off, !frequency.isDue(lastSuccessfulSyncAt: lastSuccessfulSync) {
            return
        }

        await syncService.syncAndApplyToProgress()
    }
}
