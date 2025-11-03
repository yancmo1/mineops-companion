import Foundation

/// Manages snapshot history persistence and retrieval.
@MainActor
public final class SnapshotManager {
  public static let shared = SnapshotManager()
  
  private let snapshotsFileURL: URL
  private var snapshots: [ImportSnapshot] = []
  
  private init() {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    let appDir = appSupport.appendingPathComponent("MineOpsCompanion", isDirectory: true)
    snapshotsFileURL = appDir.appendingPathComponent("import_snapshots.json")
    
    try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
    loadSnapshots()
  }
  
  /// Saves a new snapshot to history.
  public func saveSnapshot(_ snapshot: ImportSnapshot) {
    snapshots.insert(snapshot, at: 0)
    
    // Keep only the last 50 snapshots
    if snapshots.count > 50 {
      snapshots = Array(snapshots.prefix(50))
    }
    
    persistSnapshots()
  }
  
  /// Returns all snapshots, newest first.
  public func getAllSnapshots() -> [ImportSnapshot] {
    snapshots
  }
  
  /// Deletes a specific snapshot.
  public func deleteSnapshot(_ snapshot: ImportSnapshot) {
    snapshots.removeAll { $0.id == snapshot.id }
    persistSnapshots()
  }
  
  /// Clears all snapshot history.
  public func clearAll() {
    snapshots.removeAll()
    persistSnapshots()
  }
  
  private func loadSnapshots() {
    guard FileManager.default.fileExists(atPath: snapshotsFileURL.path) else { return }
    
    do {
      let data = try Data(contentsOf: snapshotsFileURL)
      snapshots = try JSONDecoder().decode([ImportSnapshot].self, from: data)
    } catch {
      print("Failed to load snapshots: \(error)")
      snapshots = []
    }
  }
  
  private func persistSnapshots() {
    do {
      let data = try JSONEncoder().encode(snapshots)
      try data.write(to: snapshotsFileURL, options: .atomic)
    } catch {
      print("Failed to save snapshots: \(error)")
    }
  }
}
