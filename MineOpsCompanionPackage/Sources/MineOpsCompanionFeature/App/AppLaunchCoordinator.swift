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
        await syncService.syncAndApplyToProgress()
    }
}
