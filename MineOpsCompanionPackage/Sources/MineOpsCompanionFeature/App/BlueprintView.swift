import SwiftUI

struct BlueprintView: View {
    var body: some View {
        ZStack {
            Color.mineDark.ignoresSafeArea()
            VStack(spacing: MineOpsLayout.sectionSpacing) {
                Text("Blueprint")
                    .mineOpsHeadingStyle()

                CardContainer(title: "Network Map") {
                    BlueprintDiagram()
                        .frame(height: 220)
                }

                CardContainer(title: "Next Actions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Align Dr. Lilly with Edmund for transport spike.")
                            .mineOpsBody()
                        Text("2. Schedule Gavin for mineshaft speed-up during events.")
                            .mineOpsBody()
                    }
                }
            }
            .padding()
        }
    }
}

private struct BlueprintDiagram: View {
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                Circle()
                    .stroke(Color.accentCyan.opacity(0.2), lineWidth: 1)
                    .frame(width: geometry.size.width * 0.7)
                diagramNode("Mine", center, 0)
                diagramNode("Transport", center, .pi * 0.6)
                diagramNode("Warehouse", center, -.pi * 0.6)
            }
        }
    }

    private func diagramNode(_ label: String, _ center: CGPoint, _ angle: CGFloat) -> some View {
        let radius: CGFloat = 80
        let position = CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
        return Circle()
            .fill(Color.mineDarkLight)
            .overlay(Text(label).mineOpsCaption())
            .frame(width: 80, height: 80)
            .overlay(
                Circle()
                    .stroke(Color.accentCyan.opacity(0.6), lineWidth: 2)
            )
            .position(position)
            .shadow(color: Color.accentCyan.opacity(0.3), radius: 6)
    }
}

#Preview("Blueprint") {
    BlueprintView()
        .preferredColorScheme(.dark)
}
