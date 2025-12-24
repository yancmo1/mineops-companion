import Foundation

/// Lightweight feature flags backed by UserDefaults.
///
/// These are intentionally simple and safe: defaults are OFF unless explicitly enabled.
public enum FeatureFlags {
  /// When enabled, runs the pill extraction V2 pipeline in parallel with legacy and logs a diff.
  public static var newPillExtractionV2Enabled: Bool {
    get { UserDefaults.standard.bool(forKey: "MineOps.NewPillExtractionV2Enabled") }
    set { UserDefaults.standard.set(newValue, forKey: "MineOps.NewPillExtractionV2Enabled") }
  }
}
