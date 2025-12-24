import SwiftUI
import Photos

struct ScreenshotImporterView: View {
    @EnvironmentObject private var review: OCRReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var progressMessage = ""
    @State private var importedNames: [String] = []
    @State private var updatedNames: [String] = []
    @State private var unchangedCount = 0
    @State private var skippedDuplicateCount = 0
    @State private var skippedNonGameCount = 0
    @State private var errorMessage: String?
    @State private var showingResetConfirm = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text(progressMessage)
                            .mineOpsBody()
                            .multilineTextAlignment(.center)
                            .padding()
                    } else if !importedNames.isEmpty || !updatedNames.isEmpty || unchangedCount > 0 || skippedDuplicateCount > 0 || skippedNonGameCount > 0 {
                        VStack(spacing: 16) {
                            Text("Import Complete")
                                .mineOpsHeadingStyle()

                        HStack(spacing: 12) {
                            summaryPill(label: "New", value: importedNames.count, systemImage: "checkmark.circle.fill", color: .green)
                            summaryPill(label: "Updated", value: updatedNames.count, systemImage: "arrow.triangle.2.circlepath.circle.fill", color: .cyan)
                            summaryPill(label: "Unchanged", value: unchangedCount, systemImage: "minus.circle.fill", color: .white.opacity(0.6))
                        }
                        
                        if !importedNames.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("New Imports:")
                                    .mineOpsBody()
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                ForEach(Array(importedNames.enumerated()), id: \.offset) { _, name in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text(name)
                                            .mineOpsBody()
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.mineDarkLight)
                            .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
                        }
                        
                        if !updatedNames.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Updated:")
                                    .mineOpsBody()
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                ForEach(Array(updatedNames.enumerated()), id: \.offset) { _, name in
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                            .foregroundStyle(.cyan)
                                        Text(name)
                                            .mineOpsBody()
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.mineDarkLight)
                            .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
                        }
                        
                        // Show skipped counts
                        VStack(spacing: 4) {
                            if skippedDuplicateCount > 0 {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text("\(skippedDuplicateCount) duplicate\(skippedDuplicateCount == 1 ? "" : "s") skipped")
                                        .mineOpsCaption()
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            
                            if skippedNonGameCount > 0 {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.badge.minus")
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text("\(skippedNonGameCount) non-game screenshot\(skippedNonGameCount == 1 ? "" : "s") skipped")
                                        .mineOpsCaption()
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                        
                            Button("Done") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentCyan)
                            .controlSize(.large)
                            .accessibilityIdentifier("screenshotImporterDoneButton")
                        }
                    } else {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 60))
                            .foregroundColor(Color.accentCyan)
                        
                        Text("Import New Screenshots")
                            .mineOpsHeadingStyle()
                        
                        Text("This will scan your Screenshots album and import any new Super Manager cards that haven't been processed yet.")
                            .mineOpsBody()
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal)
                        
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .mineOpsCaption()
                                .padding()
                        }
                        
                        Button {
                            Task { await importNewScreenshots() }
                        } label: {
                            Label("Start Import", systemImage: "arrow.down.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentCyan)
                        .controlSize(.large)
                        .accessibilityIdentifier("screenshotImporterStartButton")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Screenshot Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if !isProcessing, (!importedNames.isEmpty || !updatedNames.isEmpty || unchangedCount > 0 || skippedDuplicateCount > 0 || skippedNonGameCount > 0) {
                        Button("Done") {
                            dismiss()
                        }
                        .accessibilityIdentifier("screenshotImporterToolbarDoneButton")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            showingResetConfirm = true
                        } label: {
                            Label("Reset Import History", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isProcessing)
                    .accessibilityLabel("Import options")
                }
            }
            .alert("Reset Import History?", isPresented: $showingResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    ScreenshotsFetcher.shared.resetImportTracking()
                    errorMessage = "Import history reset. Run import again to rescan screenshots."
                }
            } message: {
                Text("This clears the app's record of which screenshots were already processed and will cause the next import to rescan.")
            }
        }
    }
    
    @MainActor
    private func importNewScreenshots() async {
        isProcessing = true
        errorMessage = nil
        importedNames = []
        updatedNames = []
        unchangedCount = 0
        skippedDuplicateCount = 0
        skippedNonGameCount = 0
        progressMessage = "Requesting photo library access..."
        
        // Request permission
        let status = await ScreenshotsFetcher.shared.requestAuthorization()
        guard status == .authorized else {
            errorMessage = "Photo library access denied. Please enable in Settings."
            isProcessing = false
            return
        }
        
        progressMessage = "Scanning for new screenshots..."
        
        // Fetch only new screenshots (not previously processed)
        let screenshots = await ScreenshotsFetcher.shared.fetchNewScreenshots(limit: 100, onlyNewSinceLastImport: true)
        
        guard !screenshots.isEmpty else {
            // If no new screenshots since last import, try without date filter
            progressMessage = "No new screenshots since last import.\nChecking all unprocessed..."
            let allScreenshots = await ScreenshotsFetcher.shared.fetchNewScreenshots(limit: 100, onlyNewSinceLastImport: false)
            
            if allScreenshots.isEmpty {
                progressMessage = "No new screenshots found"
                isProcessing = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
                return
            }
            
            // Process the unfiltered results
            await processScreenshots(allScreenshots)
            return
        }
        
        await processScreenshots(screenshots)
    }
    
    @MainActor
    private func processScreenshots(_ screenshots: [(image: UIImage, assetId: String)]) async {
        progressMessage = "Found \(screenshots.count) new screenshot\(screenshots.count == 1 ? "" : "s")\nChecking for duplicates..."
        
        // Process each image
        let processor = OCRProcessor()
        var processedImages: [(image: UIImage, assetId: String, fingerprint: ImageFingerprint?)] = []
        
        for (index, screenshot) in screenshots.enumerated() {
            progressMessage = "Checking \(index + 1) of \(screenshots.count)..."
            
            let fingerprint = ImageHasher.fingerprint(for: screenshot.image)
            if let fingerprint {
                if ImageHashStore.shared.isDuplicate(fingerprint) {
                    print("⏭️ Skipping duplicate image \(index + 1) (hash: \(fingerprint.perceptualHash.prefix(8))...)")
                    skippedDuplicateCount += 1
                    // Still mark as processed so we don't check it again
                    ScreenshotsFetcher.shared.markAsProcessed(screenshot.assetId)
                    continue
                } else {
                    print("✅ New image \(index + 1) (hash: \(fingerprint.perceptualHash.prefix(8))...)")
                }
            } else {
                print("⚠️ Could not fingerprint image \(index + 1); importing anyway")
            }

            processedImages.append((screenshot.image, screenshot.assetId, fingerprint))
        }
        
        print("📊 Import summary: \(processedImages.count) new, \(skippedDuplicateCount) duplicates")
        
        guard !processedImages.isEmpty else {
            progressMessage = "All screenshots already imported"
            // Record import date even if all were duplicates
            ScreenshotsFetcher.shared.recordImportDate()
            isProcessing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
            return
        }
        
        // Run OCR on all non-duplicate images (validator will filter non-game screenshots)
        progressMessage = "Running OCR on \(processedImages.count) image\(processedImages.count == 1 ? "" : "s")..."
        await processor.processImages(processedImages.map(\.image))
        
        // Track how many were skipped by the SM card validator
        skippedNonGameCount = processor.skippedCount
        
        // Mark all processed screenshots and add hashes AFTER successful OCR
        let assetIds = processedImages.map(\.assetId)
        ScreenshotsFetcher.shared.markAsProcessed(assetIds)
        
        for entry in processedImages {
            if let fingerprint = entry.fingerprint {
                ImageHashStore.shared.add(fingerprint)
            }
        }
        
        // Record the import date
        ScreenshotsFetcher.shared.recordImportDate()
        
        // Harvest icons for training/labeling
        progressMessage = "Harvesting passive icons..."
        for (entry, result) in zip(processedImages, processor.results) {
            let image = entry.image
            let managerId = result.id.uuidString
            let managerName = result.directoryMatch?.name ?? result.resolvedName
            
            print("🔍 Harvesting icons for \(managerName) (ID: \(managerId))")
            let icons = IconHarvester.harvestIcons(from: image, managerId: managerId)
            print("📦 Found \(icons.count) icons to harvest")
            
            if icons.isEmpty {
                print("⚠️ No icons harvested for \(managerName) - check calibration or passive detection")
            } else {
                do {
                    try IconHarvester.saveHarvest(icons, managerId: managerId, managerName: managerName, sourceImage: image)
                    print("✅ Saved \(icons.count) icons for \(managerName)")
                } catch {
                    print("❌ Failed to save harvest for \(managerName): \(error)")
                }
            }
        }
        
        // Merge results and track updates vs new imports
        let mergeResult = review.replaceAndTrackChanges(with: processor.results)
        
        // Extract names for display
        importedNames = mergeResult.newImports.map { result in
            result.directoryMatch?.name ?? result.resolvedName
        }
        updatedNames = mergeResult.updates.map { result in
            result.directoryMatch?.name ?? result.resolvedName
        }
        unchangedCount = mergeResult.unchanged.count
        
        // Create snapshot
        if !processor.results.isEmpty {
            let snapshot = ImportSnapshot.create(from: review.recognized)
            SnapshotManager.shared.saveSnapshot(snapshot)
        }
        
        isProcessing = false
    }

    @ViewBuilder
    private func summaryPill(label: String, value: Int, systemImage: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text("\(label): \(value)")
                .mineOpsCaption()
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.mineDarkLight)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}
