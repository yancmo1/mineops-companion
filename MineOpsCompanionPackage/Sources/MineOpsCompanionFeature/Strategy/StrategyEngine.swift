import Foundation

public enum StrategyEngine {
  public struct Summary: Equatable {
    public let text: String
    public init(text: String) { self.text = text }
  }

  // Normalize ids/names/aliases for matching
  private static func norm(_ s: String) -> String {
    s.lowercased()
      .replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: "’", with: "")
      .replacingOccurrences(of: "'", with: "")
      .replacingOccurrences(of: " ", with: "_")
  }

  private static func have(_ needle: String, in roster: [RecognizedSM]) -> Bool {
    let want = norm(needle)
    return roster.contains { r in
      guard let m = r.directoryMatch else { return false }
      let cands = [m.id, m.name] + (m.aliases ?? [])
      return cands.map(norm).contains(want)
    }
  }

  private static func level(_ idOrName: String, from roster: [RecognizedSM]) -> Int? {
    let want = norm(idOrName)
    return roster.first { r in
      guard let m = r.directoryMatch else { return false }
      let cands = [m.id, m.name] + (m.aliases ?? [])
      return cands.map(norm).contains(want)
    }?.level
  }

  private static func topBoosters(_ roster: [RecognizedSM], limit: Int = 3) -> String {
    let items = roster.compactMap { r -> (String, String, Double, String)? in
      guard r.primaryBoostScore > 0 else { return nil }
      let name = r.directoryMatch?.name ?? r.resolvedName
      let display = r.primaryBoostString
      return (name, r.departmentDisplay, r.primaryBoostScore, display)
    }
    .sorted { $0.2 > $1.2 }
    .prefix(limit)

    guard !items.isEmpty else { return "" }
    let lines = items.map { "- \($0.0): \($0.3) \($0.1)" }
    return "Top Super Managers by Boost:\n" + lines.joined(separator: "\n")
  }

  public static func generate(from roster: [RecognizedSM]) -> Summary {
    let plan: String

    if have("thalia", in: roster),
       have("dr_lilly", in: roster),
       have("mr_edmund", in: roster),
       have("mr_turner", in: roster) {

      let lTurner = level("mr_turner", from: roster) ?? 0
      plan =
      """
      Thalia → Lilly → Edmund + Turner
      1) Thalia 5m stream to Elevator
      2) Lilly 5m beam E→W (overlap)
      3) Mark 45–60s to clear ramp, then Edmund 2m burst
      4) Turner \(lTurner)s 30s inside Edmund window
      """
    }
    else if have("chester", in: roster),
            have("dr_lilly", in: roster),
            have("mr_edmund", in: roster),
            have("mr_turner", in: roster) {

      plan =
      """
      Chester → Lilly → Edmund + Turner
      Stuff crate with Chester, beam with Lilly, finish with Edmund; fire Turner when miners are walking in.
      """
    }
    else if have("h4v0c", in: roster),
            have("dr_lilly", in: roster) {

      plan = "H4V0C + Lilly bypass: multiply every 4th drop and beam past E/W bottlenecks."
    }
    else if have("damian_jones", in: roster),
            have("mr_edmund", in: roster) {

      plan =
      """
      Damian → Edmund (+ Turner)
      1) Damian 5m to sprint E (buy cheap E lvls if promoted)
      2) Mark 45s to clear ramp, Edmund 2m burst
      3) Time Turner’s 30s when miners are already walking in
      """
    }
    else {
      plan = "Need at least one of: (Thalia/Chester/H4V0C), plus (Lilly/Damian), plus (Edmund/Mark)."
    }

    let boosters = topBoosters(roster)
    return .init(text: boosters.isEmpty ? plan : "\(boosters)\n\n\(plan)")
  }
}
