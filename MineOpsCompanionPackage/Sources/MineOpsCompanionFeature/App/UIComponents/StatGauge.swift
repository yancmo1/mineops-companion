import SwiftUI

/// Circular gauge used for quick progress readouts.
public struct StatGauge: View {
    public let label: String
    public let value: String
    public let progress: Double
    public let color: Color

    public init(label: String, value: String, progress: Double, color: Color) {
        self.label = label
        self.value = value
        self.progress = progress
        self.color = color
    }

    public var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.mineDarkLight, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(clampedProgress))
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value)
                    .font(.headline)
                    .foregroundStyle(Color.white)
            }
            .frame(width: 88, height: 88)
            Text(label)
                .mineOpsCaption()
        }
        .frame(maxWidth: .infinity)
    }

    private var clampedProgress: Double {
        max(0, min(progress, 1))
    }
}
