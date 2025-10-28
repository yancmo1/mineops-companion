import Foundation

public enum StrategyEngine {
  public struct Summary: Equatable {
    public let text: String
    public init(text: String) { self.text = text }
  }

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
      let candidates = [m.id, m.name] + (m.aliases ?? [])
      return candidates.map(norm).contains(want)
    }
  }

  private static func level(_ needle: String, in roster: [RecognizedSM]) -> Int? {
    let want = norm(needle)
    return roster.first { r in
      guard let m = r.directoryMatch else { return false }
      let candidates = [m.id, m.name] + (m.aliases ?? [])
      return candidates.map(norm).contains(want)
    }?.level
  }

  public static func generate(from roster: [RecognizedSM]) -> Summary {
    if have("thalia", in: roster), have("dr_lilly", in: roster), have("mr_edmund", in: roster), have("mr_turner", in: roster) {
      let lTurner = level("mr_turner", in: roster) ?? 0
      return .init(text:
        """
        Thalia -> Lilly -> Edmund + Turner
        1) Thalia 5m stream to Elevator
        2) Lilly 5m beam E->W (overlap)
        3) Mark 45-60s to clear ramp, then Edmund 2m burst
        4) Turner \(lTurner)s 30s inside Edmund window
        """
      )
    }

    if have("chester", in: roster), have("dr_lilly", in: roster), have("mr_edmund", in: roster), have("mr_turner", in: roster) {
      return .init(text:
        """
        Chester -> Lilly -> Edmund + Turner
        Stuff crate with Chester, beam with Lilly, finish with Edmund; fire Turner when miners are walking in.
        """
      )
    }

    if have("h4v0c", in: roster), have("dr_lilly", in: roster) {
      return .init(text: "H4V0C + Lilly bypass: multiply every 4th drop and beam past E/W bottlenecks.")
    }

    if have("damian_jones", in: roster), have("mr_edmund", in: roster) {
      return .init(text:
        """
        Damian -> Edmund (+ Turner)
        1) Damian 5m to sprint E (buy cheap E levels if promoted)
        2) Mark 45s to clear ramp, Edmund 2m burst
        3) Time Turner's 30s when miners are already walking in
        """
      )
    }

    return .init(text: "Need at least one of: (Thalia/Chester/H4V0C), plus (Lilly/Damian), plus (Edmund/Mark).")
  }
}
