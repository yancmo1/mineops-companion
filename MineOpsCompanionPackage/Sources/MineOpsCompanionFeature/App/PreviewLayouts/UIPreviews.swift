import SwiftUI

struct MineOpsUIPreviews: View {
    var body: some View {
        NavigationStack {
            TabView {
                CommandCenterViewV2()
                    .tabItem { Label("Command V2", systemImage: "sparkles") }
                PocketAssistantView()
                    .tabItem { Label("Assistant", systemImage: "brain.head.profile") }
                BlueprintView()
                    .tabItem { Label("Blueprint", systemImage: "map.fill") }
                ChronicleView()
                    .tabItem { Label("Strategies", systemImage: "book.closed.fill") }
                OrbitView()
                    .tabItem { Label("Orbit", systemImage: "globe.americas.fill") }
            }
            .tint(.accentCyan)
            .background(Color.mineDark.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("MineOps Companion")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("Dashboard Tabs") {
    MineOpsUIPreviews()
        .preferredColorScheme(.dark)
}

#Preview("Command V2") {
    CommandCenterViewV2()
        .preferredColorScheme(.dark)
}
