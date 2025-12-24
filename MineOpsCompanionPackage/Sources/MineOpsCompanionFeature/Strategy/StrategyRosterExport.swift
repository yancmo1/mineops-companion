import Foundation

/// A compact, prompt-friendly view of a manager.
///
/// We keep this intentionally small and numeric-first to reduce hallucinations:
/// - prefer multipliers/durations/levels over free-form text
/// - include elements when present
/// - include equipment placeholders until detection is implemented
struct StrategyRosterExportEntry: Codable, Hashable {
    let name: String
    let department: String

    let levelCurrent: Int?
    let levelMax: Int?

    let promotionCurrent: Int?
    let promotionMax: Int?

    let activeMultiplier: Double?
    let activeDurationSeconds: Int?
    let activeCooldownSeconds: Int?

    let passiveMultiplier: Double?
    let passiveDurationSeconds: Int?
    let passiveUnlockedCount: Int?
    let passiveUnlockedTotal: Int?

    let elements: [String]
    let equipmentSlots: [String]

    init(from sm: RecognizedSM) {
        self.name = sm.resolvedName

        if let explicitRole = sm.role, !explicitRole.isEmpty {
            self.department = explicitRole
        } else if let dept = sm.directoryMatch?.department {
            self.department = dept.capitalized
        } else {
            self.department = "Unknown"
        }

        if let fraction = sm.stats.level {
            self.levelCurrent = fraction.current
            self.levelMax = fraction.total
        } else {
            self.levelCurrent = sm.level
            self.levelMax = nil
        }

        if let promo = sm.stats.promotion {
            self.promotionCurrent = promo.current
            self.promotionMax = promo.total
        } else {
            self.promotionCurrent = nil
            self.promotionMax = nil
        }

        let directoryActive = sm.directoryMatch?.active

        self.activeMultiplier = StrategyRosterExportEntry.bestMultiplier(
            explicit: sm.active.multiplier,
            directoryFallback: directoryActive?.multiplier,
            statsFallback: sm.stats
        )

        self.activeDurationSeconds = sm.active.durationSeconds
            ?? directoryActive?.durationSeconds
            ?? sm.stats.durationPair.map { $0.duration * 60 }

        self.activeCooldownSeconds = sm.active.cooldownSeconds
            ?? directoryActive?.cooldownSeconds
            ?? sm.stats.durationPair.map { $0.cooldown * 60 }

        self.passiveMultiplier = sm.passive.multiplier
        self.passiveDurationSeconds = sm.passive.durationSeconds

        if sm.passive.unlockedSlots.isEmpty {
            self.passiveUnlockedCount = nil
            self.passiveUnlockedTotal = nil
        } else {
            self.passiveUnlockedCount = sm.passive.unlockedSlots.filter { $0 }.count
            self.passiveUnlockedTotal = sm.passive.unlockedSlots.count
        }

        self.elements = sm.directoryMatch?.elements ?? []

        // Until equipment detection is implemented, make this explicit so the model does not assume bonuses.
        self.equipmentSlots = ["Unknown", "Unknown", "Unknown"]
    }

    var promptLine: String {
        var parts: [String] = []
        parts.append("Name: \(name)")
        parts.append("Dept: \(department)")

        if let current = levelCurrent {
            if let max = levelMax {
                parts.append("Level: \(current)/\(max)")
            } else {
                parts.append("Level: \(current)")
            }
        }

        if let current = promotionCurrent {
            if let max = promotionMax {
                parts.append("Promotion: \(current)/\(max)")
            } else {
                parts.append("Promotion: \(current)")
            }
        }

        if let mult = activeMultiplier {
            parts.append(String(format: "ActiveMult: %.2fx", mult))
        }
        if let duration = activeDurationSeconds {
            parts.append("ActiveDur: \(duration)s")
        }
        if let cd = activeCooldownSeconds {
            parts.append("ActiveCD: \(cd)s")
        }

        if let mult = passiveMultiplier {
            parts.append(String(format: "PassiveMult: %.2fx", mult))
        }
        if let duration = passiveDurationSeconds {
            parts.append("PassiveDur: \(duration)s")
        }
        if let unlocked = passiveUnlockedCount, let total = passiveUnlockedTotal {
            parts.append("Passives: \(unlocked)/\(total) unlocked")
        }

        if !elements.isEmpty {
            parts.append("Elements: \(elements.joined(separator: ", "))")
        } else {
            parts.append("Elements: Unknown")
        }

        parts.append("Equipment: [\(equipmentSlots.joined(separator: ", "))]")
        return parts.joined(separator: " | ")
    }

    private static func bestMultiplier(explicit: Double?, directoryFallback: Double?, statsFallback stats: SMStats) -> Double? {
        if let explicit { return explicit }
        if let directoryFallback { return directoryFallback }
        if let first = stats.multipliersDescending.first?.value { return first }

        // As a last resort, try converting the first percent token into a multiplier.
        if let percent = stats.percentNumberValues.first {
            return 1.0 + (percent / 100.0)
        }

        return nil
    }
}
