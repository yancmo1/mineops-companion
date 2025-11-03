import Photos
import UIKit

/// Fetches and monitors screenshots from the Photos library.
public final class ScreenshotsFetcher: NSObject, @unchecked Sendable, PHPhotoLibraryChangeObserver {
  public static let shared = ScreenshotsFetcher()
  
  private var screenshotsCollection: PHAssetCollection?
  private let processedIDsLock = NSLock()
  private var _processedIdentifiers = Set<String>()
  private var processedIdentifiers: Set<String> {
    get {
      processedIDsLock.lock()
      defer { processedIDsLock.unlock() }
      return _processedIdentifiers
    }
    set {
      processedIDsLock.lock()
      defer { processedIDsLock.unlock() }
      _processedIdentifiers = newValue
    }
  }
  private let processedIDsKey = "com.mineops.processedScreenshotIDs"
  
  public var onNewScreenshot: (@Sendable (UIImage) -> Void)?
  
  private override init() {
    super.init()
    loadProcessedIdentifiers()
    PHPhotoLibrary.shared().register(self)
  }
  
  deinit {
    PHPhotoLibrary.shared().unregisterChangeObserver(self)
  }
  
  /// Requests photo library authorization.
  public func requestAuthorization() async -> PHAuthorizationStatus {
    await PHPhotoLibrary.requestAuthorization(for: .readWrite)
  }
  
  /// Fetches the most recent screenshot.
  public func fetchMostRecentScreenshot() async -> UIImage? {
    guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
      return nil
    }
    
    let collection = getScreenshotsCollection()
    
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    fetchOptions.fetchLimit = 1
    
    let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
    guard let asset = assets.firstObject else {
      return nil
    }
    
    // Check if already processed
    if processedIdentifiers.contains(asset.localIdentifier) {
      return nil
    }
    
    return await loadImage(from: asset)
  }
  
  /// Fetches recent screenshots (up to limit). Does NOT filter by processed status - that's handled by image hash deduplication.
  public func fetchUnprocessedScreenshots(limit: Int = 10) async -> [UIImage] {
    guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
      return []
    }
    
    let collection = getScreenshotsCollection()
    
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    fetchOptions.fetchLimit = limit
    
    let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
    var images: [UIImage] = []
    
    for index in 0..<assets.count {
      let asset = assets[index]
      
      if let image = await loadImage(from: asset) {
        images.append(image)
      }
    }
    
    return images
  }
  
  /// Marks a screenshot as processed to avoid reprocessing.
  public func markAsProcessed(_ identifier: String) {
    processedIdentifiers.insert(identifier)
    persistProcessedIdentifiers()
  }
  
  /// Clears all processed identifiers (for testing/reset).
  public func clearProcessedIdentifiers() {
    processedIdentifiers.removeAll()
    persistProcessedIdentifiers()
  }
  
  // MARK: - PHPhotoLibraryChangeObserver
  
  nonisolated public func photoLibraryDidChange(_ changeInstance: PHChange) {
    guard let collection = screenshotsCollection else { return }
    
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
    
    guard let changes = changeInstance.changeDetails(for: assets) else { return }
    
    if changes.hasIncrementalChanges {
      Task { @MainActor in
        // Process newly inserted screenshots
        for asset in changes.insertedObjects {
          guard !self.processedIdentifiers.contains(asset.localIdentifier) else {
            continue
          }
          
          if let image = await self.loadImage(from: asset) {
            self.markAsProcessed(asset.localIdentifier)
            self.onNewScreenshot?(image)
          }
        }
      }
    }
  }
  
  // MARK: - Private Helpers
  
  private func getScreenshotsCollection() -> PHAssetCollection {
    if let existing = screenshotsCollection {
      return existing
    }
    
    let collections = PHAssetCollection.fetchAssetCollections(
      with: .smartAlbum,
      subtype: .smartAlbumScreenshots,
      options: nil
    )
    
    let collection = collections.firstObject ?? PHAssetCollection()
    screenshotsCollection = collection
    return collection
  }
  
  private func loadImage(from asset: PHAsset) async -> UIImage? {
    await withCheckedContinuation { continuation in
      let options = PHImageRequestOptions()
      options.isSynchronous = false
      options.deliveryMode = .highQualityFormat
      options.isNetworkAccessAllowed = true
      
      PHImageManager.default().requestImage(
        for: asset,
        targetSize: PHImageManagerMaximumSize,
        contentMode: .aspectFit,
        options: options
      ) { image, _ in
        continuation.resume(returning: image)
      }
    }
  }
  
  private func loadProcessedIdentifiers() {
    if let data = UserDefaults.standard.data(forKey: processedIDsKey),
       let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
      processedIdentifiers = ids
    }
  }
  
  private func persistProcessedIdentifiers() {
    if let data = try? JSONEncoder().encode(processedIdentifiers) {
      UserDefaults.standard.set(data, forKey: processedIDsKey)
    }
  }
}
