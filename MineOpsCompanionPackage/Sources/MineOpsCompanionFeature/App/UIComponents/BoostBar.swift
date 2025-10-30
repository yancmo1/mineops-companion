import SwiftUI

/// Horizontal bar visualizing boost strength.
public struct BoostBar: View {
    public let label: String
    public let boostValue: Double
    public let color: Color
    private let maxValue: Double

    public init(label: String, boostValue: Double, color: Color, maxValue: Double = 2000) {
        self.label = label
        self.boostValue = boostValue
        self.color = color
        self.maxValue = maxValue
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .mineOpsCaption()
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.mineDarkLight)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * progress)
                }
                .frame(height: 8)
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }

    private var progress: CGFloat {
        let clamped = max(min(boostValue / maxValue, 1), 0)
        return CGFloat(clamped)
    }
}
