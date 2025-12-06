import SwiftUI

/// Shared color palette for the MineOps Companion interface.
public enum MineOpsColors {
    /// Deep background used behind primary content.
    public static let background = Color(red: 11 / 255, green: 16 / 255, blue: 26 / 255)
    /// Elevated surface color for cards and panels.
    public static let card = Color(red: 21 / 255, green: 31 / 255, blue: 46 / 255)
    /// Sub-surface tint for controls and secondary groupings.
    public static let light = Color(red: 34 / 255, green: 49 / 255, blue: 64 / 255)
    /// Primary neon accent used for actionable affordances.
    public static let accentCyan = Color(red: 0.0, green: 196.0 / 255.0, blue: 222.0 / 255.0)
    /// Secondary accent that pairs with cyan for stateful highlights.
    public static let accentOrange = Color(red: 1.0, green: 165.0 / 255.0, blue: 89.0 / 255.0)
}

public extension Color {
    static let mineDark = MineOpsColors.background
    static let mineDarkCard = MineOpsColors.card
    static let mineDarkLight = MineOpsColors.light
    static let accentCyan = MineOpsColors.accentCyan
    static let accentOrange = MineOpsColors.accentOrange
}
