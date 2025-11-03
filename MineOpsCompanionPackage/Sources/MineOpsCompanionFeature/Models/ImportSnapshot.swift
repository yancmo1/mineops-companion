import Foundation

/// Represents a snapshot of imported Super Managers at a specific point in time.
public struct ImportSnapshot: Identifiable, Codable {
  public let id: UUID
  public let timestamp: Date
  public let managerIds: [UUID]
  public let totalManagers: Int
  public let byRarity: [String: Int]
  public let byDepartment: [String: Int]
  
  public init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    managerIds: [UUID],
    totalManagers: Int,
    byRarity: [String: Int],
    byDepartment: [String: Int]
  ) {
    self.id = id
    self.timestamp = timestamp
    self.managerIds = managerIds
    self.totalManagers = totalManagers
    self.byRarity = byRarity
    self.byDepartment = byDepartment
  }
  
  /// Creates a snapshot from the current manager collection.
  public static func create(from managers: [RecognizedSM]) -> ImportSnapshot {
    let managerIds = managers.map { $0.id }
    let totalManagers = managers.count
    
    var byRarity: [String: Int] = [:]
    var byDepartment: [String: Int] = [:]
    
    for manager in managers {
      if let rarity = manager.rarity {
        byRarity[rarity, default: 0] += 1
      }
      
      let dept = manager.departmentDisplay
      byDepartment[dept, default: 0] += 1
    }
    
    return ImportSnapshot(
      managerIds: managerIds,
      totalManagers: totalManagers,
      byRarity: byRarity,
      byDepartment: byDepartment
    )
  }
}
