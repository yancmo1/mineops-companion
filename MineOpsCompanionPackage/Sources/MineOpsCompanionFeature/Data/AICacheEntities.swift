import CoreData
import Foundation

@objc(CachedStrategyEntity)
final class CachedStrategyEntity: NSManagedObject {
    @NSManaged var mineName: String?
    @NSManaged var mineLevel: Int64
    @NSManaged var shaftLevel: Int64
    @NSManaged var detectedManagers: [String]?
    @NSManaged var strategyJSON: String?
    @NSManaged var timestamp: Date?
}

@objc(CachedDetectionEntity)
final class CachedDetectionEntity: NSManagedObject {
    @NSManaged var imageHash: String?
    @NSManaged var managerName: String?
    @NSManaged var timestamp: Date?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        timestamp = Date()
    }
}
