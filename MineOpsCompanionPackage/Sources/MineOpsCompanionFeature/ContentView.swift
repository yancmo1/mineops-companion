import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        TabView {
            CommandCenterViewV2()
                .tabItem {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2")
                }

            NavigationStack {
                OCRReviewView()
            }
                .tabItem {
                    Label("Manager", systemImage: "person.text.rectangle")
                }

            NavigationStack {
                StrategySummaryView()
            }
                .tabItem {
                    Label("Strategy", systemImage: "chart.bar.xaxis")
                }
        }
        .tint(.accentCyan)
    }
}
