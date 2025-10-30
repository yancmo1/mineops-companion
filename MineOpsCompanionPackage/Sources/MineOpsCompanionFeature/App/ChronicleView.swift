import SwiftUI

struct ChronicleView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MineOpsLayout.sectionSpacing) {
                Text("Strategy Chronicle")
                    .mineOpsHeadingStyle()

                ForEach(samplePlans.indices, id: \.self) { index in
                    CardContainer(title: samplePlans[index].title) {
                        Text(samplePlans[index].detail)
                            .mineOpsBody()
                        MineOpsButton(label: "View", icon: "list.bullet") {}
                    }
                }
            }
            .padding()
        }
        .background(Color.mineDark.ignoresSafeArea())
    }

    private var samplePlans: [(title: String, detail: String)] {
        [
            ("Turner Timing", "Stack Edmund + Turner for a 30s burst after mineshaft clears."),
            ("Lilly Hand-off", "Beam eastern shafts with Lilly before activating H4V0C."),
            ("Warehouse Surge", "Run Chester to prep inventory, then rotate Damian." )
        ]
    }
}

#Preview("Chronicle") {
    ChronicleView()
        .preferredColorScheme(.dark)
}
