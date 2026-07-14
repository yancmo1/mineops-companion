import SwiftUI

public struct ContentView: View {
    @State private var progressService = SMProgressService.shared
    @State private var masterService = SMMasterDataService.shared
    @State private var hasInitialized = false

    public init() {}

    public var body: some View {
        Group {
            if masterService.isLoading && !hasInitialized {
                loadingView
            } else {
                TabView {
                    V2DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "rectangle.grid.2x2")
                        }

                    V2ManagersView()
                        .tabItem {
                            Label("Managers", systemImage: "person.text.rectangle")
                        }

                    V2StrategyView()
                        .tabItem {
                            Label("Strategy", systemImage: "chart.bar.xaxis")
                        }

                    KolibriSyncView()
                        .tabItem {
                            Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                }
                .tint(.accentCyan)
                .preferredColorScheme(.light)
                .environment(progressService)
            }
        }
        .task {
            guard !hasInitialized else { return }
            hasInitialized = true

            // Load master data and progress
            await progressService.initialize()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading Super Manager data…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.mineDark.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}
