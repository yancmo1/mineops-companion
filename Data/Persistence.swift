import CoreData
import Foundation

/// Persistence handles CoreData stack setup and persistent storage
/// for OCR results and Super Manager snapshots.
struct Persistence {
    static let shared = Persistence()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MineOpsCompanion")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    /// Preview instance for SwiftUI previews
    static var preview: Persistence = {
        let result = Persistence(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Add sample data for previews if needed
        
        return result
    }()
}
