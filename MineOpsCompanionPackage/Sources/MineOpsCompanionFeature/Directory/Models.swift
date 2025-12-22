import Foundation

public struct SMDirectoryEntry: Decodable, Identifiable, Hashable {
  public struct Active: Decodable, Hashable {
    public let name: String
    public let type: String
    public let durationSeconds: Int
    public let cooldownSeconds: Int
    public let multiplier: Double?
    public let description: String?
  }
  public struct Passive: Decodable, Hashable {
    public let kind: String
    public let value: Double
    public let unlocked: Bool?
    public let level: Int?
    public let description: String?
  }

  public let id: String
  public let name: String
  public let department: String   // "mineshaft" | "elevator" | "warehouse"
  public let rarity: String
  public let elements: [String]?  // e.g., ["Nature", "Water", "Sand"]
  public let active: Active?
  public let passives: [Passive]?
  public let aliases: [String]?
  public let notes: String?
  public let availableByHiring: Bool?
  public let availableInBriefcases: Bool?

  enum K: CodingKey {
    case id, name, department, rarity, elements, active, passives, aliases, notes
    case availableByHiring, availableInBriefcases
    // legacy keys we normalize:
    case role, boostType, baseBoost, maxBoost, availability, cost, synergy, imageName
  }

  public init(from d: Decoder) throws {
    let c = try d.container(keyedBy: K.self)

    // New-schema fast path
    if c.contains(.department) || c.contains(.active) {
      id         = try c.decodeIfPresent(String.self, forKey: .id) ?? Self.slug(try c.decode(String.self, forKey: .name))
      name       = try c.decode(String.self, forKey: .name)
      department = try c.decode(String.self, forKey: .department)
      rarity     = try c.decodeIfPresent(String.self, forKey: .rarity) ?? "unknown"
      elements   = try c.decodeIfPresent([String].self, forKey: .elements)
      active     = try c.decodeIfPresent(Active.self, forKey: .active)
      passives   = try c.decodeIfPresent([Passive].self, forKey: .passives)
      aliases    = try c.decodeIfPresent([String].self, forKey: .aliases)
      notes      = try c.decodeIfPresent(String.self, forKey: .notes)
      availableByHiring    = try c.decodeIfPresent(Bool.self, forKey: .availableByHiring)
      availableInBriefcases = try c.decodeIfPresent(Bool.self, forKey: .availableInBriefcases)
      return
    }

    // Legacy-schema → normalize
    let rawName  = try c.decode(String.self, forKey: .name)
    let rawRole  = try c.decode(String.self, forKey: .role)        // "Mine" | "Transport" | "Warehouse"
    let boost    = try c.decodeIfPresent(Int.self, forKey: .baseBoost) ?? 0
    let boostLbl = try c.decodeIfPresent(String.self, forKey: .boostType) ?? "Boost"
    let image    = try c.decodeIfPresent(String.self, forKey: .imageName)

    var canonID = image ?? Self.slug(rawName)
    if rawName.lowercased() == "h4v0c" { canonID = "h4v0c" }

    var dept = Self.mapDepartment(fromRole: rawRole)
    let corrections: [String:String] = [
      "Dr. Lilly": "elevator",
      "Chris Capella": "warehouse",
      "Lee Vatori": "elevator"
    ]
    if let fix = corrections[rawName] { dept = fix }

    id         = canonID
    name       = rawName
    department = dept
    rarity     = "unknown"
    elements   = nil
    let mult   = boost > 0 ? Double(boost)/100.0 : nil
    active     = Active(
      name: boostLbl,
      type: Self.slug(boostLbl),
      durationSeconds: Self.defaultDuration(for: rawName),
      cooldownSeconds: 900,
      multiplier: mult,
      description: nil
    )
    passives   = nil
    var alias  = [rawName.replacingOccurrences(of: ".", with: "")]
    if rawName == "H4V0C" { alias.append(contentsOf: ["HAVOC","H4VOC"]) }
    aliases    = alias
    notes      = nil
    availableByHiring     = nil
    availableInBriefcases = nil
  }

  static func slug(_ s: String) -> String {
    s.lowercased()
      .replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: "’", with: "")
      .replacingOccurrences(of: "'", with: "")
      .replacingOccurrences(of: " ", with: "_")
  }

  static func mapDepartment(fromRole role: String) -> String {
    switch role.lowercased() {
    case "mine": return "mineshaft"
    case "transport": return "elevator"
    case "warehouse": return "warehouse"
    default: return role.lowercased()
    }
  }

  static func defaultDuration(for name: String) -> Int {
    switch name {
    case "Mr. Edmund": return 120
    case "H4V0C": return 180
    default: return 300
    }
  }
}

public enum SMDirectory {
  public static func load() throws -> [SMDirectoryEntry] {
    try ResourceLoader.decode([SMDirectoryEntry].self, from: "sm_directory")
  }
}
