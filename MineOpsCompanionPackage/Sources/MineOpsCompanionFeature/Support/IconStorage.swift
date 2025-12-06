import Foundation

public enum IconStorage {
    public static func ensureDirectories() {
        let manager = FileManager.default
        guard let docs = try? manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return
        }

        let folders = [
            docs.appendingPathComponent("SMIcons/unlocked", isDirectory: true),
            docs.appendingPathComponent("SMIcons/locked", isDirectory: true)
        ]

        for folder in folders where !manager.fileExists(atPath: folder.path) {
            do {
                try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            } catch {
                print("⚠️ Failed to create icon directory at \(folder.path): \(error.localizedDescription)")
            }
        }
    }
}
