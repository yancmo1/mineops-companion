import SwiftUI

struct OrbitView: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [.mineDark, .accentCyan.opacity(0.3)], center: .center, startRadius: 60, endRadius: 400)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Performance Orbit")
                    .mineOpsHeadingStyle()
                ZStack {
                    ForEach(0..<orbitalPoints.count, id: \.self) { index in
                        OrbitDot(item: orbitalPoints[index])
                    }
                }
                .frame(width: 240, height: 240)
            }
        }
    }

    private var orbitalPoints: [OrbitItem] {
        [
            OrbitItem(label: "Mine", angle: 0, color: .accentOrange),
            OrbitItem(label: "Transport", angle: 72, color: .accentCyan),
            OrbitItem(label: "Warehouse", angle: 144, color: .purple),
            OrbitItem(label: "Event", angle: 216, color: .pink),
            OrbitItem(label: "Idle", angle: 288, color: .green)
        ]
    }
}

private struct OrbitItem {
    let label: String
    let angle: Double
    let color: Color
}

private struct OrbitDot: View {
    let item: OrbitItem

    var body: some View {
        GeometryReader { geometry in
            let radius = geometry.size.width / 2.5
            let radian = item.angle * .pi / 180
            let position = CGPoint(
                x: geometry.size.width / 2 + cos(radian) * radius,
                y: geometry.size.height / 2 + sin(radian) * radius
            )

            ZStack {
                Circle()
                    .fill(item.color)
                    .frame(width: 24, height: 24)
                    .shadow(color: item.color.opacity(0.4), radius: 6)
                Text(item.label.prefix(1))
                    .font(.caption2.bold())
                    .foregroundStyle(Color.white)
            }
            .position(position)
        }
    }
}

#Preview("Orbit") {
    OrbitView()
        .preferredColorScheme(.dark)
}
