import SwiftUI

/// Compact metric tile used for dashboard summaries.
public struct QuickStat: View {
    public let title: String
    public let value: String
    public let color: Color

    public init(title: String, value: String, color: Color) {
        self.title = title
        self.value = value
        self.color = color
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .mineOpsCaption()
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.mineDarkCard)
        .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
        .shadow(color: color.opacity(0.15), radius: 5)
    }
}
