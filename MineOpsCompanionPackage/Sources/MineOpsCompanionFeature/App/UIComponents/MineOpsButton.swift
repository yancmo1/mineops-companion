import SwiftUI

/// Primary button style used across the app.
public struct MineOpsButton: View {
    public let label: String
    public let icon: String
    public let action: () -> Void

    public init(label: String, icon: String, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label)
                    .font(.headline)
            }
            .foregroundStyle(Color.accentCyan)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.mineDarkLight)
            .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius)
                    .stroke(Color.accentCyan.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
