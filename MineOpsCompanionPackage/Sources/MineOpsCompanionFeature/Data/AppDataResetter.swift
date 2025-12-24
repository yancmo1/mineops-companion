import CoreData
import Foundation
import OSLog

/// Central place to clear user data (managers, history, caches).
///
/// Intentionally does **not** clear the OpenAI API key (stored in Keychain) so you don't have to re-enter it.
@MainActor
public enum AppDataResetter {
    public static func clearAllUserData() {
        Logger.storage.info("🧹 Clearing all user data")

        // Recognized managers + overrides + stored images
        Persistence.shared.clearRecognizedManagers()

        // Import snapshots
        SnapshotManager.shared.clearAll()

        // Duplicate detection hashes
        ImageHashStore.shared.clearAll()

        // Strategy cache/history (Core Data)
        clearCoreDataEntity(named: "CachedStrategy")

        Logger.storage.info("✅ Cleared all user data")
    }

    private static func clearCoreDataEntity(named entityName: String) {
        let context = CoreDataManager.shared.container.viewContext

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            if let result = try context.execute(deleteRequest) as? NSBatchDeleteResult,
               let objectIDs = result.result as? [NSManagedObjectID],
               !objectIDs.isEmpty {
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs], into: [context])
            }
            CoreDataManager.shared.saveContext()
        } catch {
            Logger.storage.error("❌ Failed clearing CoreData entity \(entityName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
