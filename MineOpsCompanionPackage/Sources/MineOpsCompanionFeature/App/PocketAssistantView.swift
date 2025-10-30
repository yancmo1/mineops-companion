import SwiftUI

struct PocketAssistantView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MineOpsLayout.sectionSpacing) {
                Text("Pocket Assistant")
                    .mineOpsHeadingStyle()

                CardContainer(title: "Insights") {
                    Text("Warehouse managers are under-performing. Consider reallocating boosts before the next prestige.")
                        .mineOpsBody()
                }

                CardContainer(title: "Upgrade Queue") {
                    ForEach(sampleQueue, id: \.self) { item in
                        HStack {
                            Text(item)
                                .mineOpsBody()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.accentCyan)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
        }
        .background(Color.mineDark.ignoresSafeArea())
    }

    private var sampleQueue: [String] {
        [
            "Promote Mr. Turner to 10/10",
            "Unlock Dr. Lilly synergy node",
            "Refit warehouse boosters"
        ]
    }
}

#Preview("Pocket Assistant") {
    PocketAssistantView()
        .preferredColorScheme(.dark)
}
