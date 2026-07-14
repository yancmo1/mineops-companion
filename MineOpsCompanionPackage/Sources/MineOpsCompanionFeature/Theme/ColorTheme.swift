import SwiftUI

/// Shared color palette for the MineOps Companion interface.
public enum MineOpsColors {
    /// Main app background — light gray.
    public static let background = Color(red: 242 / 255, green: 244 / 255, blue: 247 / 255)
    /// Elevated surface color for cards and panels — white.
    public static let card = Color.white
    /// Sub-surface tint for controls and secondary groupings — light gray.
    public static let light = Color(red: 228 / 255, green: 232 / 255, blue: 238 / 255)
    /// Primary accent — teal/cyan.
    public static let accentCyan = Color(red: 0.0, green: 160.0 / 255.0, blue: 185.0 / 255.0)
    /// Secondary accent — orange.
    public static let accentOrange = Color(red: 1.0, green: 140.0 / 255.0, blue: 50.0 / 255.0)
}

public extension Color {
    static let mineDark = MineOpsColors.background
    static let mineDarkCard = MineOpsColors.card
    static let mineDarkLight = MineOpsColors.light
    static let accentCyan = MineOpsColors.accentCyan
    static let accentOrange = MineOpsColors.accentOrange
}
