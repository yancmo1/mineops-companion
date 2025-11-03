import Foundation

/// Manages image hash storage to detect duplicate imports.
@MainActor
public final class ImageHashStore {
  public static let shared = ImageHashStore()
  
  private let hashFileURL: URL
  private var imageHashes: Set<String> = []
  
  private init() {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    let appDir = appSupport.appendingPathComponent("MineOpsCompanion", isDirectory: true)
    hashFileURL = appDir.appendingPathComponent("image_hashes.json")
    
    try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
    loadHashes()
  }
  
  /// Checks if an image hash already exists in the store.
  public func isDuplicate(_ hash: String) -> Bool {
    // Check exact match first
    if imageHashes.contains(hash) {
      return true
    }
    
    // Check for similar hashes (Hamming distance <= 3)
    // Strict threshold to avoid false positives with game UI layouts
    for existingHash in imageHashes {
      if ImageHasher.areSimilar(hash, existingHash, threshold: 3) {
        return true
      }
    }
    
    return false
  }
  
  /// Adds a new hash to the store.
  public func addHash(_ hash: String) {
    imageHashes.insert(hash)
    persistHashes()
  }
  
  /// Removes a hash from the store (e.g., when deleting a manager).
  public func removeHash(_ hash: String) {
    imageHashes.remove(hash)
    persistHashes()
  }
  
  /// Clears all stored hashes.
  public func clearAll() {
    imageHashes.removeAll()
    persistHashes()
  }
  
  /// Returns the total number of unique hashes stored.
  public func count() -> Int {
    imageHashes.count
  }
  
  private func loadHashes() {
    guard FileManager.default.fileExists(atPath: hashFileURL.path) else { return }
    
    do {
      let data = try Data(contentsOf: hashFileURL)
      let hashArray = try JSONDecoder().decode([String].self, from: data)
      imageHashes = Set(hashArray)
    } catch {
      print("Failed to load image hashes: \(error)")
      imageHashes = []
    }
  }
  
  private func persistHashes() {
    do {
      let hashArray = Array(imageHashes)
      let data = try JSONEncoder().encode(hashArray)
      try data.write(to: hashFileURL, options: .atomic)
    } catch {
      print("Failed to save image hashes: \(error)")
    }
  }
}
