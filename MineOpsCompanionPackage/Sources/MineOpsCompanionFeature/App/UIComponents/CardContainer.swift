import SwiftUI

/// Rounded neon-style container used to frame grouped content.
public struct CardContainer<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .mineOpsCardTitle()
                    .padding(.bottom, 4)
            }
            content
        }
        .padding(MineOpsLayout.cardPadding)
        .background(Color.mineDarkCard)
        .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius)
                .stroke(Color.accentCyan.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.accentCyan.opacity(0.1), radius: 6)
    }
}
