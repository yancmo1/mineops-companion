import SwiftUI

/// A `CardContainer` with a tappable header that expands/collapses the card content.
public struct CollapsibleCardContainer<Content: View>: View {
    private let title: String
    private let titleColor: Color
    private let content: Content
    private let accessibilityIdentifier: String?

    @State private var isExpanded: Bool

    public init(
        title: String,
        titleColor: Color = .accentCyan,
        defaultExpanded: Bool = true,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.titleColor = titleColor
        self._isExpanded = State(initialValue: defaultExpanded)
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content()
    }

    public var body: some View {
        CardContainer(title: nil) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Text(title)
                        .mineOpsCardTitle()
                        .foregroundStyle(titleColor)

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(titleColor.opacity(0.9))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse \(title)" : "Expand \(title)")
            .accessibilityIdentifier(toggleIdentifier)

            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var toggleIdentifier: String {
        if let accessibilityIdentifier {
            return "\(accessibilityIdentifier)_toggle"
        }
        // Reasonable default that still lets UI tests target it if needed.
        return "collapsibleCard_\(title.replacingOccurrences(of: " ", with: ""))_toggle"
    }
}
