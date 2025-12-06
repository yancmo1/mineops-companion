import SwiftUI
import MineOpsCompanionFeature
import OSLog

@main
struct MineOpsCompanionApp: App {
    @StateObject private var review = OCRReviewViewModel()
    @State private var processLatestScreenshot = false

    init() {
        #if DEBUG
        clearAllDataForTesting()
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
    
    private func clearAllDataForTesting() {
        let fm = FileManager.default
        
        // Clear Documents directory
        if let docsURL = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let filesToDelete = [
                "recognized_managers.json",
                "image_hashes.json",
                "import_snapshots.json"
            ]
            
            for filename in filesToDelete {
                let fileURL = docsURL.appendingPathComponent(filename)
                try? fm.removeItem(at: fileURL)
            }
            
            // Clear saved images
            let imagesDir = docsURL.appendingPathComponent("Images", isDirectory: true)
            try? fm.removeItem(at: imagesDir)
            
            // Clear harvested icons
            let iconsDir = docsURL.appendingPathComponent("Icons", isDirectory: true)
            try? fm.removeItem(at: iconsDir)
        }
        
        // Clear Application Support directory
        if let appSupportURL = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            // Remove entire app support directory and recreate
            try? fm.removeItem(at: appSupportURL)
            try? fm.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }
        
        // Clear UserDefaults (including calibration data)
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        
        // Clear in-memory hash store
        Task { @MainActor in
            ImageHashStore.shared.clearAll()
        }
        
        Logger.app.info("✅ Cleared all app data for testing build (Documents, App Support, UserDefaults, Hash Store)")
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

