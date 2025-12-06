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
  private let lastImportDateKey = "com.mineops.lastImportDate"
  
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
  
  /// The date of the last successful import, used to filter older screenshots
  public var lastImportDate: Date? {
    get { UserDefaults.standard.object(forKey: lastImportDateKey) as? Date }
    set { UserDefaults.standard.set(newValue, forKey: lastImportDateKey) }
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
  
  /// Fetches new screenshots that haven't been processed yet.
  /// Uses asset identifiers to track what's been seen.
  /// - Parameters:
  ///   - limit: Maximum number of screenshots to fetch
  ///   - onlyNewSinceLastImport: If true, only fetch screenshots taken after the last import date
  /// - Returns: Array of (image, assetIdentifier) tuples for new screenshots
  public func fetchNewScreenshots(limit: Int = 100, onlyNewSinceLastImport: Bool = true) async -> [(image: UIImage, assetId: String)] {
    guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
      return []
    }
    
    let collection = getScreenshotsCollection()
    
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    
    // Filter by date if we have a last import date and onlyNewSinceLastImport is true
    if onlyNewSinceLastImport, let lastDate = lastImportDate {
      fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastDate as NSDate)
      print("📅 Filtering screenshots newer than: \(lastDate)")
    }
    
    let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
    var results: [(image: UIImage, assetId: String)] = []
    var checkedCount = 0
    
    print("📸 Found \(assets.count) screenshots to check")
    
    for index in 0..<assets.count {
      guard results.count < limit else { break }
      
      let asset = assets[index]
      checkedCount += 1
      
      // Skip already processed screenshots
      if processedIdentifiers.contains(asset.localIdentifier) {
        print("⏭️ Already processed: \(asset.localIdentifier.prefix(8))...")
        continue
      }
      
      if let image = await loadImage(from: asset) {
        results.append((image, asset.localIdentifier))
      }
    }
    
    print("📊 Checked \(checkedCount) screenshots, found \(results.count) new ones")
    return results
  }
  
  /// Legacy method - fetches recent screenshots without tracking.
  /// Prefer fetchNewScreenshots() for the import workflow.
  public func fetchUnprocessedScreenshots(limit: Int = 10) async -> [UIImage] {
    let results = await fetchNewScreenshots(limit: limit, onlyNewSinceLastImport: false)
    return results.map(\.image)
  }
  
  /// Marks a screenshot as processed to avoid reprocessing.
  public func markAsProcessed(_ identifier: String) {
    processedIdentifiers.insert(identifier)
    persistProcessedIdentifiers()
  }
  
  /// Marks multiple screenshots as processed.
  public func markAsProcessed(_ identifiers: [String]) {
    for id in identifiers {
      processedIdentifiers.insert(id)
    }
    persistProcessedIdentifiers()
  }
  
  /// Records the current date as the last import date.
  public func recordImportDate() {
    lastImportDate = Date()
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
