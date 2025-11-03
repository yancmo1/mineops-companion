import CoreData
import Foundation

@MainActor
final class CoreDataManager {
    static let shared = CoreDataManager()

    let container: NSPersistentContainer

    private init() {
        let modelName = "AICacheModel"
        let bundle = Bundle.module

        guard
            let modelURL = bundle.url(forResource: modelName, withExtension: "momd") ??
                bundle.url(forResource: modelName, withExtension: "mom"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("AICacheModel.momd missing from bundle")
        }

        container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSSQLiteStoreType
        description.url = Self.defaultStoreURL()
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Failed to load Core Data store: \(error)")
            }
        }

        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save Core Data context: \(error)")
        }
    }

    private static func defaultStoreURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let container = base.appendingPathComponent("MineOpsCompanion", isDirectory: true)
        try? fm.createDirectory(at: container, withIntermediateDirectories: true)
        return container.appendingPathComponent("AICache.sqlite")
    }
}
