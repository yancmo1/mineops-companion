import SwiftUI

/// Canonical typography presets for MineOps Companion.
public enum MineOpsFont {
    public static let heading = Font.system(size: 24, weight: .bold, design: .rounded)
    public static let subheading = Font.system(size: 18, weight: .semibold, design: .rounded)
    public static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    public static let caption = Font.system(size: 13, weight: .regular, design: .rounded)
}

public extension View {
    func mineOpsHeadingStyle() -> some View {
        font(MineOpsFont.heading)
            .foregroundStyle(Color.accentCyan)
    }

    func mineOpsCardTitle() -> some View {
        font(MineOpsFont.subheading)
            .foregroundStyle(Color.white)
    }

    func mineOpsBody() -> some View {
        font(MineOpsFont.body)
            .foregroundStyle(Color.white.opacity(0.9))
    }

    func mineOpsCaption() -> some View {
        font(MineOpsFont.caption)
            .foregroundStyle(Color.gray)
    }
}
