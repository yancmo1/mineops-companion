import Photos
import SwiftUI
import UIKit

/// A custom in-app photo browser that opens directly to the Screenshots album.
/// This avoids the system PhotosPicker memory issues and provides faster access.
struct ScreenshotsBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var assets: PHFetchResult<PHAsset>?
    @State private var selectedAssets: Set<String> = []
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    let onImport: ([UIImage]) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if authorizationStatus == .notDetermined {
                    requestAccessView
                } else if authorizationStatus == .authorized || authorizationStatus == .limited {
                    if isLoading {
                        ProgressView("Loading Screenshots...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let assets, assets.count > 0 {
                        screenshotsGrid(assets: assets)
                    } else {
                        emptyStateView
                    }
                } else {
                    deniedAccessView
                }
            }
            .background(Color.mineDark.ignoresSafeArea())
            .navigationTitle("Screenshots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if !selectedAssets.isEmpty {
                        Button("Import (\(selectedAssets.count))") {
                            Task { await importSelected() }
                        }
                        .disabled(isImporting)
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    if let assets, assets.count > 0 {
                        HStack {
                            Button("Select All") {
                                selectAll()
                            }
                            Spacer()
                            Text("\(assets.count) screenshots")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Clear") {
                                selectedAssets.removeAll()
                            }
                        }
                    }
                }
            }
            .overlay {
                if isImporting {
                    ZStack {
                        Color.black.opacity(0.5)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Importing \(selectedAssets.count) screenshots...")
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                        .background(Color.mineDarkCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .task {
            await checkAuthorizationAndLoad()
        }
    }
    
    // MARK: - Subviews
    
    private var requestAccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentCyan)
            
            Text("Photo Access Required")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("MineOps needs access to your Photos to import Super Manager screenshots.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button("Allow Access") {
                Task { await requestAccess() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentCyan)
        }
        .padding()
    }
    
    private var deniedAccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            
            Text("Photo Access Denied")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Please enable Photos access in Settings to import screenshots.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentCyan)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentCyan.opacity(0.5))
            
            Text("No Screenshots")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Take screenshots of your Super Managers in Idle Miner Tycoon to import them here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private func screenshotsGrid(assets: PHFetchResult<PHAsset>) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<assets.count, id: \.self) { index in
                    let asset = assets[index]
                    ScreenshotThumbnailView(
                        asset: asset,
                        isSelected: selectedAssets.contains(asset.localIdentifier)
                    )
                    .frame(height: 180)
                    .clipped()
                    .onTapGesture {
                        toggleSelection(asset.localIdentifier)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Actions
    
    private func checkAuthorizationAndLoad() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            await loadScreenshots()
        }
    }
    
    private func requestAccess() async {
        authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            await loadScreenshots()
        }
    }
    
    private func loadScreenshots() async {
        isLoading = true
        
        // Find Screenshots smart album
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        )
        
        guard let screenshotsAlbum = collections.firstObject else {
            isLoading = false
            return
        }
        
        // Fetch screenshots sorted by newest first
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchedAssets = PHAsset.fetchAssets(in: screenshotsAlbum, options: fetchOptions)
        
        await MainActor.run {
            assets = fetchedAssets
            isLoading = false
        }
    }
    
    private func toggleSelection(_ identifier: String) {
        if selectedAssets.contains(identifier) {
            selectedAssets.remove(identifier)
        } else {
            selectedAssets.insert(identifier)
        }
    }
    
    private func selectAll() {
        guard let assets else { return }
        // Limit to first 50 to avoid memory issues
        let limit = min(assets.count, 50)
        for i in 0..<limit {
            selectedAssets.insert(assets[i].localIdentifier)
        }
    }
    
    private func importSelected() async {
        guard let assets, !selectedAssets.isEmpty else { return }
        
        isImporting = true
        
        var images: [UIImage] = []
        
        // Load selected images with memory-efficient options
        for i in 0..<assets.count {
            let asset = assets[i]
            guard selectedAssets.contains(asset.localIdentifier) else { continue }
            
            if let image = await loadImage(from: asset) {
                images.append(image)
            }
            
            // Process in batches to reduce memory pressure
            if images.count >= 10 {
                // Yield to let autoreleasepool clean up
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        
        await MainActor.run {
            isImporting = false
            onImport(images)
            dismiss()
        }
    }
    
    private func loadImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .exact
            
            // Request at a reasonable size to avoid memory issues
            let targetSize = CGSize(width: 1290, height: 2796) // iPhone 15 Pro Max resolution
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // Only resume once - PHImageManager may call this multiple times
                guard !hasResumed else { return }
                
                // Only accept the final image (not degraded placeholder)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }
}

// MARK: - Thumbnail View

private struct ScreenshotThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.mineDarkLight
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
            }
            
            // Selection indicator
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentCyan : Color.black.opacity(0.5))
                    .frame(width: 24, height: 24)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.7), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(6)
        }
        .task(id: asset.localIdentifier) {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat  // Get single fast thumbnail only
        options.resizeMode = .fast
        
        // Higher resolution thumbnails for better quality
        let targetSize = CGSize(width: 400, height: 800)
        
        // Use async/await pattern that handles single callback
        let image: UIImage? = await withCheckedContinuation { continuation in
            var hasResumed = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                // Only resume once - PHImageManager may call this multiple times
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
        
        await MainActor.run {
            thumbnail = image
        }
    }
}
