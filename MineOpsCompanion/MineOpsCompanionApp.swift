import SwiftUI
import MineOpsCompanionFeature
import OSLog

@main
struct MineOpsCompanionApp: App {
    @StateObject private var review = OCRReviewViewModel()
    @State private var processLatestScreenshot = false

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
                .environmentObject(review)
                .onOpenURL { url in
                    handleURLScheme(url)
                }
                .task {
                    if processLatestScreenshot {
                        await processLatestScreenshotFromShortcut()
                        processLatestScreenshot = false
                    }
                }
        }
    }
    
    private func handleURLScheme(_ url: URL) {
        guard url.scheme == "mineops" else { return }
        
        if url.host == "process-latest" || url.path == "/process-latest" {
            processLatestScreenshot = true
        }
    }
    
    @MainActor
    private func processLatestScreenshotFromShortcut() async {
        let status = await ScreenshotsFetcher.shared.requestAuthorization()
        guard status == .authorized else { return }
        
        guard let image = await ScreenshotsFetcher.shared.fetchMostRecentScreenshot() else {
            return
        }
        
        // Check for duplicates
        if let fingerprint = ImageHasher.fingerprint(for: image) {
            if ImageHashStore.shared.isDuplicate(fingerprint) {
                return // Skip duplicate
            }
            ImageHashStore.shared.add(fingerprint)
        }
        
        // Process the screenshot through OCR
        let processor = OCRProcessor()
        await processor.processImages([image])
        
        // Merge results into review model
        review.replace(with: processor.results)
        
        // Create snapshot
        if !processor.results.isEmpty {
            let snapshot = ImportSnapshot.create(from: review.recognized)
            SnapshotManager.shared.saveSnapshot(snapshot)
        }
    }
}

