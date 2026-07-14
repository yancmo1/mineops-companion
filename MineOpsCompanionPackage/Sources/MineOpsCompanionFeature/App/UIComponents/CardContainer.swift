import SwiftUI

/// Rounded neon-style container used to frame grouped content.
public struct CardContainer<Content: View>: View {
    private let title: String?
    private let titleColor: Color
    private let content: Content

    public init(title: String? = nil, titleColor: Color = .accentCyan, @ViewBuilder content: () -> Content) {
        self.title = title
        self.titleColor = titleColor
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .mineOpsCardTitle()
                    .foregroundStyle(titleColor)
                    .padding(.bottom, 4)
            }
            content
        }
        .padding(MineOpsLayout.cardPadding)
        .background(Color.mineDarkCard)
        .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius)
                .stroke(Color.accentCyan.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity)
    }
}
