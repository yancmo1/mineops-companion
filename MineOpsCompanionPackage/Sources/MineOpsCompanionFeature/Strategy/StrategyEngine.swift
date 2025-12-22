import Foundation

public enum StrategyEngine {
  public struct BurstStep: Identifiable, Equatable {
    public let id = UUID()
    public let order: Int
    public let title: String          // e.g. "Prime Elevator"
    public let managerName: String    // e.g. "Damian Jones"
    public let role: String           // e.g. "Elevator", "Mineshaft", "Warehouse"
    public let startOffsetSeconds: Int
    public let durationSeconds: Int
  }

  public struct Summary: Equatable {
    public let text: String
    public let burstSteps: [BurstStep]

    public init(text: String, burstSteps: [BurstStep] = []) {
      self.text = text
      self.burstSteps = burstSteps
    }

    public static func == (lhs: Summary, rhs: Summary) -> Bool {
      lhs.text == rhs.text && lhs.burstSteps == rhs.burstSteps
    }
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

  private static func smName(for id: String, in roster: [RecognizedSM]) -> String {
    roster.first { $0.directoryMatch?.id == id }?.directoryMatch?.name ?? id
  }

  private static func makeStep(
    order: Int,
    title: String,
    managerId: String,
    role: String,
    start: Int,
    duration: Int,
    roster: [RecognizedSM]
  ) -> BurstStep {
    BurstStep(
      order: order,
      title: title,
      managerName: smName(for: managerId, in: roster),
      role: role,
      startOffsetSeconds: start,
      durationSeconds: duration
    )
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

    // Build burst steps
    let hasDamian   = have("damian_jones", in: roster)
    let hasSojo     = have("sojo", in: roster)
    let hasLee      = have("lee_vatori", in: roster)
    let hasThalia   = have("thalia", in: roster)
    let hasFreesia  = have("freesia", in: roster)
    let hasH4V0C    = have("h4v0c", in: roster)
    let hasEdmund   = have("mr_edmund", in: roster)
    let hasTurner   = have("mr_turner", in: roster)
    let hasLuxario  = have("luxario", in: roster)
    let hasAlTitude = have("al_titude", in: roster)
    let hasMark     = have("mark", in: roster)

    var burstSteps: [BurstStep] = []

    // Step 1: Elevator booster (Damian > Sojo > Lee)
    if hasDamian {
      burstSteps.append(
        makeStep(order: 1,
                 title: "Prime Elevator",
                 managerId: "damian_jones",
                 role: "Elevator",
                 start: 0,
                 duration: 300,
                 roster: roster)
      )
    } else if hasSojo {
      burstSteps.append(
        makeStep(order: 1,
                 title: "Prime Elevator",
                 managerId: "sojo",
                 role: "Elevator",
                 start: 0,
                 duration: 300,
                 roster: roster)
      )
    } else if hasLee {
      burstSteps.append(
        makeStep(order: 1,
                 title: "Prime Elevator",
                 managerId: "lee_vatori",
                 role: "Elevator",
                 start: 0,
                 duration: 300,
                 roster: roster)
      )
    }

    // Step 2: Initial shaft wave (Thalia or Freesia)
    if hasThalia {
      burstSteps.append(
        makeStep(order: 2,
                 title: "Start Shaft Wave",
                 managerId: "thalia",
                 role: "Mineshaft",
                 start: 0,
                 duration: 90,
                 roster: roster)
      )
    } else if hasFreesia {
      burstSteps.append(
        makeStep(order: 2,
                 title: "Start Shaft Wave",
                 managerId: "freesia",
                 role: "Mineshaft",
                 start: 0,
                 duration: 60,
                 roster: roster)
      )
    }

    // Step 3: Swap to H4V0C for burst
    if hasH4V0C {
      burstSteps.append(
        makeStep(order: 3,
                 title: "Swap to Burst Shaft",
                 managerId: "h4v0c",
                 role: "Mineshaft",
                 start: 60,
                 duration: 180,
                 roster: roster)
      )
    }

    // Step 4: Edmund warehouse burst
    if hasEdmund {
      burstSteps.append(
        makeStep(order: 4,
                 title: "Warehouse Burst Window",
                 managerId: "mr_edmund",
                 role: "Warehouse",
                 start: 90,
                 duration: 120,
                 roster: roster)
      )
    }

    // Step 5: Turner cash-out inside Edmund
    if hasTurner {
      burstSteps.append(
        makeStep(order: 5,
                 title: "Cash-out Inside Edmund",
                 managerId: "mr_turner",
                 role: "Mineshaft",
                 start: 150,
                 duration: 30,
                 roster: roster)
      )
    }

    // Step 6: Filler warehouse manager between bursts
    if hasLuxario || hasAlTitude || hasMark {
      let fillerId: String
      let fillerTitle: String

      if hasLuxario {
        fillerId = "luxario"
        fillerTitle = "Luxario Fill Cycle"
      } else if hasAlTitude {
        fillerId = "al_titude"
        fillerTitle = "Al Titude Fill Cycle"
      } else {
        fillerId = "mark"
        fillerTitle = "Mark Fill Cycle"
      }

      burstSteps.append(
        makeStep(order: 6,
                 title: fillerTitle,
                 managerId: fillerId,
                 role: "Warehouse",
                 start: 210,
                 duration: 120,
                 roster: roster)
      )
    }

    let boosters = topBoosters(roster)
    let summaryText = boosters.isEmpty ? plan : "\(boosters)\n\n\(plan)"
    
    return Summary(text: summaryText, burstSteps: burstSteps)
  }
}
