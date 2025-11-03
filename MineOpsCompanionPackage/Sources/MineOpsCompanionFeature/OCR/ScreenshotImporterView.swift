import SwiftUI
import Photos

struct ScreenshotImporterView: View {
    @EnvironmentObject private var review: OCRReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var progressMessage = ""
    @State private var importedNames: [String] = []
    @State private var updatedNames: [String] = []
    @State private var skippedCount = 0
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text(progressMessage)
                        .mineOpsBody()
                        .multilineTextAlignment(.center)
                        .padding()
                } else if !importedNames.isEmpty || !updatedNames.isEmpty || skippedCount > 0 {
                    VStack(spacing: 16) {
                        Text("Import Complete")
                            .mineOpsHeadingStyle()
                        
                        if !importedNames.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("New Imports:")
                                    .mineOpsBody()
                                    .foregroundStyle(.secondary)
                                
                                ForEach(importedNames, id: \.self) { name in
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
                                    .foregroundStyle(.secondary)
                                
                                ForEach(updatedNames, id: \.self) { name in
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
                        
                        if skippedCount > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.secondary)
                                Text("\(skippedCount) duplicate\(skippedCount == 1 ? "" : "s") skipped")
                                    .mineOpsCaption()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentCyan)
                        .controlSize(.large)
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
                        .foregroundStyle(.secondary)
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
                }
            }
            .padding()
            .navigationTitle("Screenshot Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }
    
    @MainActor
    private func importNewScreenshots() async {
        isProcessing = true
        errorMessage = nil
        importedNames = []
        updatedNames = []
        skippedCount = 0
        progressMessage = "Requesting photo library access..."
        
        // Request permission
        let status = await ScreenshotsFetcher.shared.requestAuthorization()
        guard status == .authorized else {
            errorMessage = "Photo library access denied. Please enable in Settings."
            isProcessing = false
            return
        }
        
        progressMessage = "Scanning Screenshots album..."
        
        // Fetch unprocessed screenshots (limit to 100 to avoid overwhelming)
        let images = await ScreenshotsFetcher.shared.fetchUnprocessedScreenshots(limit: 100)
        
        guard !images.isEmpty else {
            progressMessage = "No new screenshots found"
            isProcessing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
            return
        }
        
        progressMessage = "Found \(images.count) screenshot\(images.count == 1 ? "" : "s")\nChecking for duplicates..."
        
        // Process each image
        let processor = OCRProcessor()
        var processedImages: [UIImage] = []
        
        for (index, image) in images.enumerated() {
            progressMessage = "Checking \(index + 1) of \(images.count)..."
            
            // Check for duplicate hash
            if let hash = ImageHasher.perceptualHash(for: image) {
                if await ImageHashStore.shared.isDuplicate(hash) {
                    print("⏭️ Skipping duplicate image \(index + 1) (hash: \(hash.prefix(8))...)")
                    skippedCount += 1
                    continue
                } else {
                    print("✅ New image \(index + 1) (hash: \(hash.prefix(8))...)")
                }
            }
            
            processedImages.append(image)
        }
        
        print("📊 Import summary: \(processedImages.count) new, \(skippedCount) duplicates")
        
        guard !processedImages.isEmpty else {
            progressMessage = "All screenshots already imported"
            isProcessing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
            return
        }
        
        // Run OCR on all non-duplicate images
        progressMessage = "Running OCR on \(processedImages.count) image\(processedImages.count == 1 ? "" : "s")..."
        await processor.processImages(processedImages)
        
        // Add hashes AFTER successful OCR
        for image in processedImages {
            if let hash = ImageHasher.perceptualHash(for: image) {
                ImageHashStore.shared.addHash(hash)
            }
        }
        
        // Harvest icons for training/labeling
        progressMessage = "Harvesting passive icons..."
        for (image, result) in zip(processedImages, processor.results) {
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
        
        // Create snapshot
        if !processor.results.isEmpty {
            let snapshot = ImportSnapshot.create(from: review.recognized)
            SnapshotManager.shared.saveSnapshot(snapshot)
        }
        
        isProcessing = false
    }
}
