import Foundation

/// Persists mine-specific settings using UserDefaults.
/// Each mine type (Mainland, Continents) and continent mine has its own stored settings.
@MainActor
@Observable
final class MineSettingsStore {
    static let shared = MineSettingsStore()
    
    private let defaults = UserDefaults.standard
    private let keyPrefix = "MineOps.MineSettings."
    
    private init() {}
    
    // MARK: - Settings Keys
    
    /// Key for mine type level settings (prestige, maxShaft, etc.)
    private func key(for mineType: MineType, continentMine: ContinentMine?, suffix: String) -> String {
        let typeKey = mineType.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
        if let mine = continentMine, mineType.continentMines != nil {
            return "\(keyPrefix)\(typeKey).\(mine.rawValue.lowercased()).\(suffix)"
        }
        return "\(keyPrefix)\(typeKey).\(suffix)"
    }
    
    // MARK: - Mainland Settings
    
    var mainlandMineNumber: Int {
        get { defaults.integer(forKey: "\(keyPrefix)mainland.mineNumber").nonZero ?? 1 }
        set { defaults.set(newValue, forKey: "\(keyPrefix)mainland.mineNumber") }
    }

    // MARK: - Numbered Progression (Mainland / Frontier)

    func mineNumber(for mineType: MineType) -> Int {
        // Back-compat: keep using the original mainland key.
        if mineType == .mainland {
            return mainlandMineNumber
        }
        let key = key(for: mineType, continentMine: nil, suffix: "mineNumber")
        if defaults.object(forKey: key) == nil {
            return 1
        }
        return max(1, defaults.integer(forKey: key))
    }

    func setMineNumber(_ value: Int, for mineType: MineType) {
        if mineType == .mainland {
            mainlandMineNumber = value
            return
        }
        let key = key(for: mineType, continentMine: nil, suffix: "mineNumber")
        defaults.set(value, forKey: key)
    }
    
    // MARK: - Per-Mine Settings
    
    func prestige(for mineType: MineType, continentMine: ContinentMine? = nil) -> Int {
        let prestigeKey = key(for: mineType, continentMine: continentMine, suffix: "prestige")
        // UserDefaults returns 0 for missing keys; 0 is a valid prestige value.
        if defaults.object(forKey: prestigeKey) == nil {
            return 0
        }
        return max(0, defaults.integer(forKey: prestigeKey))
    }
    
    func setPrestige(_ value: Int, for mineType: MineType, continentMine: ContinentMine? = nil) {
        defaults.set(value, forKey: key(for: mineType, continentMine: continentMine, suffix: "prestige"))
    }
    
    func maxShaft(for mineType: MineType, continentMine: ContinentMine? = nil) -> Int {
        defaults.integer(forKey: key(for: mineType, continentMine: continentMine, suffix: "maxShaft")).nonZero ?? 30
    }
    
    func setMaxShaft(_ value: Int, for mineType: MineType, continentMine: ContinentMine? = nil) {
        defaults.set(value, forKey: key(for: mineType, continentMine: continentMine, suffix: "maxShaft"))
    }
    
    func hasBarrier(for mineType: MineType, continentMine: ContinentMine? = nil) -> Bool {
        defaults.bool(forKey: key(for: mineType, continentMine: continentMine, suffix: "hasBarrier"))
    }
    
    func setHasBarrier(_ value: Bool, for mineType: MineType, continentMine: ContinentMine? = nil) {
        defaults.set(value, forKey: key(for: mineType, continentMine: continentMine, suffix: "hasBarrier"))
    }
    
    func barriersRemoved(for mineType: MineType, continentMine: ContinentMine? = nil) -> Int {
        defaults.integer(forKey: key(for: mineType, continentMine: continentMine, suffix: "barriersRemoved"))
    }
    
    func setBarriersRemoved(_ value: Int, for mineType: MineType, continentMine: ContinentMine? = nil) {
        defaults.set(value, forKey: key(for: mineType, continentMine: continentMine, suffix: "barriersRemoved"))
    }
    
    // MARK: - Selected Mine Type
    
    var selectedMineType: MineType {
        get {
            guard let typeString = defaults.string(forKey: "\(keyPrefix)selectedMineType"),
                  let type = MineType(rawValue: typeString) else {
                return .mainland
            }
            return type
        }
        set {
            defaults.set(newValue.rawValue, forKey: "\(keyPrefix)selectedMineType")
        }
    }
    
    /// The selected continent mine for each continent (stored per-continent)
    func selectedContinentMine(for mineType: MineType) -> ContinentMine {
        let typeKey = mineType.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
        guard let mineName = defaults.string(forKey: "\(keyPrefix)\(typeKey).selectedContinentMine"),
              let mine = ContinentMine(rawValue: mineName) else {
            return mineType.continentMines?.first ?? .ruby
        }
        return mine
    }
    
    func setSelectedContinentMine(_ mine: ContinentMine, for mineType: MineType) {
        let typeKey = mineType.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
        defaults.set(mine.rawValue, forKey: "\(keyPrefix)\(typeKey).selectedContinentMine")
    }
}

// MARK: - Helpers

private extension Int {
    /// Returns nil if self is 0 (useful for UserDefaults which returns 0 for missing keys)
    var nonZero: Int? {
        self == 0 ? nil : self
    }
}
