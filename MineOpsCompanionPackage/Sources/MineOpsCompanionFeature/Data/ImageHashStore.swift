import Foundation

/// Manages image fingerprint storage to detect duplicate imports.
@MainActor
public final class ImageHashStore {
  public static let shared = ImageHashStore()

  enum StorageDestination {
    case appSupport
    case inMemory
    case custom(URL)
  }

  private let storage: StorageDestination
  private let hashFileURL: URL?
  private var fingerprints: Set<ImageFingerprint> = []

  init(storage: StorageDestination = .appSupport) {
    self.storage = storage

    switch storage {
    case .appSupport:
      let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
      let appDir = appSupport.appendingPathComponent("MineOpsCompanion", isDirectory: true)
      try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
      hashFileURL = appDir.appendingPathComponent("image_hashes.json")
    case .custom(let url):
      hashFileURL = url
      if let fileURL = hashFileURL {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      }
    case .inMemory:
      hashFileURL = nil
    }

    loadFingerprints()
  }

  /// Checks if a fingerprint already exists in the store.
  public func isDuplicate(_ fingerprint: ImageFingerprint) -> Bool {
    if fingerprints.contains(fingerprint) {
      return true
    }

    if let digest = fingerprint.pixelDigest,
       fingerprints.contains(where: { $0.pixelDigest == digest }) {
      return true
    }

    if fingerprints.contains(where: { $0.pixelDigest == nil && $0.perceptualHash == fingerprint.perceptualHash }) {
      return true
    }

    return false
  }

  /// Adds a new fingerprint to the store.
  public func add(_ fingerprint: ImageFingerprint) {
    fingerprints.insert(fingerprint)
    persistFingerprints()
  }

  /// Removes a fingerprint from the store (e.g., when deleting a manager).
  public func remove(_ fingerprint: ImageFingerprint) {
    fingerprints.remove(fingerprint)
    persistFingerprints()
  }

  /// Clears all stored fingerprints.
  public func clearAll() {
    fingerprints.removeAll()
    persistFingerprints()
  }

  /// Returns the total number of unique fingerprints stored.
  public func count() -> Int {
    fingerprints.count
  }

  private func loadFingerprints() {
    guard let url = hashFileURL,
          FileManager.default.fileExists(atPath: url.path) else { return }

    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      if let decoded = try? decoder.decode([ImageFingerprint].self, from: data) {
        fingerprints = Set(decoded)
        return
      }

      let legacy = try decoder.decode([String].self, from: data)
      fingerprints = Set(legacy.map { ImageFingerprint.legacy($0) })
      persistFingerprints() // migrate to new format
    } catch {
      print("Failed to load image hashes: \(error)")
      fingerprints = []
    }
  }

  private func persistFingerprints() {
    guard let url = hashFileURL else { return }
    do {
      let data = try JSONEncoder().encode(Array(fingerprints))
      try data.write(to: url, options: .atomic)
    } catch {
      print("Failed to save image hashes: \(error)")
    }
  }
}
