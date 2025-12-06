import Foundation

struct IconLegend: Codable {
    let version: String
    let lastUpdated: String
    let icons: [IconInfo]
}

struct IconInfo: Codable, Identifiable {
    let id: String
    let displayName: String
    let description: String
    let iconUnlocked: String
    let iconLocked: String
    let boostCategory: String

    var unlockedAssetName: String { (iconUnlocked as NSString).deletingPathExtension }
    var lockedAssetName: String { (iconLocked as NSString).deletingPathExtension }
}
