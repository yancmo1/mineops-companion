import SwiftUI
import MineOpsCompanionFeature
import OSLog

@main
struct MineOpsCompanionApp: App {

    init() {
        #if DEBUG
        // Optional dev-only reset: launch with "--reset-data" to wipe local data.
        if ProcessInfo.processInfo.arguments.contains("--reset-data") {
            AppDataResetter.clearAllUserData()
        }
        #endif
        IconStorage.ensureDirectories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

