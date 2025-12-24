import CoreGraphics
import Testing
@testable import MineOpsCompanionFeature

struct SMCardPillTokenAssignerTests {

  @Test
  func assignsActiveDurationCooldownAndValues() {
    let imageSize = CGSize(width: 1170, height: 2532)

    // Simulate typical layout:
    // - Active time pills on left side (top: duration, below: cooldown)
    // - Active value pill on left bottom
    // - Passive value pill(s) on right bottom
    let tokens: [SMCardPillExtractor.Token] = [
      .init(raw: "5m", kind: .duration(seconds: 300), confidence: 0.95, rect: CGRect(x: 650, y: 1950, width: 120, height: 60)),
      .init(raw: "30m", kind: .duration(seconds: 1800), confidence: 0.96, rect: CGRect(x: 650, y: 2070, width: 120, height: 60)),
      .init(raw: "8.08x", kind: .multiplier(8.08), confidence: 0.92, rect: CGRect(x: 140, y: 2090, width: 190, height: 70)),
      .init(raw: "-14.5%", kind: .percent(-14.5), confidence: 0.91, rect: CGRect(x: 720, y: 2100, width: 190, height: 70))
    ]

    let mapping = SMCardPillTokenAssigner.assign(tokens: tokens, imageSize: imageSize)

    #expect(mapping.activeDurationSeconds == 300)
    #expect(mapping.activeCooldownSeconds == 1800)
    #expect(mapping.activeMultiplier == 8.08)

    // Percent tokens convert to multiplier.
    let expectedPassive = 1.0 + (-14.5 / 100.0)
    #expect(mapping.passiveMultiplier == expectedPassive)
  }

  @Test
  func prefersHigherConfidenceEvenIfWeaker() {
    let imageSize = CGSize(width: 1170, height: 2532)

    let tokens: [SMCardPillExtractor.Token] = [
      .init(raw: "37x", kind: .multiplier(37.0), confidence: 0.55, rect: CGRect(x: 160, y: 2100, width: 200, height: 70)),
      .init(raw: "-91.88%", kind: .percent(-91.88), confidence: 0.93, rect: CGRect(x: 170, y: 2105, width: 220, height: 70))
    ]

    let mapping = SMCardPillTokenAssigner.assign(tokens: tokens, imageSize: imageSize)

    // Should pick the higher confidence token even if the strength is lower.
    let expected = 1.0 + (-91.88 / 100.0)
    #expect(mapping.activeMultiplier == expected)
  }

  @Test
  func v2CapturesAllPassiveValuesWithUnitsAndOrdering() {
    let imageSize = CGSize(width: 1170, height: 2532)

    let tokens: [SMCardPillExtractor.Token] = [
      // Left-side active values
      .init(raw: "5m", kind: .duration(seconds: 300), confidence: 0.92, rect: CGRect(x: 140, y: 1940, width: 120, height: 60)),
      .init(raw: "30m", kind: .duration(seconds: 1800), confidence: 0.93, rect: CGRect(x: 140, y: 2060, width: 120, height: 60)),
      .init(raw: "8.08x", kind: .multiplier(8.08), confidence: 0.90, rect: CGRect(x: 140, y: 2180, width: 190, height: 70)),

      // Right-side passive list (top->bottom)
      .init(raw: "-14.5%", kind: .percent(-14.5), confidence: 0.91, rect: CGRect(x: 760, y: 1980, width: 190, height: 70)),
      .init(raw: "1.25x", kind: .multiplier(1.25), confidence: 0.88, rect: CGRect(x: 760, y: 2100, width: 190, height: 70)),
      .init(raw: "-3%", kind: .percent(-3.0), confidence: 0.86, rect: CGRect(x: 760, y: 2220, width: 190, height: 70))
    ]

    let mapping = SMCardPillTokenAssigner.assignV2(tokens: tokens, imageSize: imageSize)

    #expect(mapping.activeMultiplier == 8.08)
    #expect(mapping.activeDurationSeconds == 300)
    #expect(mapping.activeCooldownSeconds == 1800)

    #expect(mapping.passive.count == 3)
    #expect(mapping.passive[0].slot == 0)
    #expect(mapping.passive[0].raw == "-14.5%")
    #expect(mapping.passive[0].unit == .percent)
    #expect(mapping.passive[0].value == -14.5)
    #expect(mapping.passive[0].derivedMultiplier == 1.0 + (-14.5 / 100.0))

    #expect(mapping.passive[1].slot == 1)
    #expect(mapping.passive[1].raw == "1.25x")
    #expect(mapping.passive[1].unit == .multiplier)
    #expect(mapping.passive[1].value == 1.25)
    #expect(mapping.passive[1].derivedMultiplier == 1.25)

    #expect(mapping.passive[2].slot == 2)
    #expect(mapping.passive[2].raw == "-3%")
    #expect(mapping.passive[2].unit == .percent)
    #expect(mapping.passive[2].value == -3.0)
    #expect(mapping.passive[2].derivedMultiplier == 1.0 + (-3.0 / 100.0))
  }

  @Test
  func v2SwapsDurationAndCooldownWhenInverted() {
    let imageSize = CGSize(width: 1170, height: 2532)

    let tokens: [SMCardPillExtractor.Token] = [
      // Inverted on purpose: top shows 30m, below shows 5m
      .init(raw: "30m", kind: .duration(seconds: 1800), confidence: 0.95, rect: CGRect(x: 140, y: 1940, width: 120, height: 60)),
      .init(raw: "5m", kind: .duration(seconds: 300), confidence: 0.95, rect: CGRect(x: 140, y: 2060, width: 120, height: 60))
    ]

    let mapping = SMCardPillTokenAssigner.assignV2(tokens: tokens, imageSize: imageSize)

    // After sanity swap: duration should be 5m (300), cooldown 30m (1800)
    #expect(mapping.activeDurationSeconds == 300)
    #expect(mapping.activeCooldownSeconds == 1800)
  }
}
