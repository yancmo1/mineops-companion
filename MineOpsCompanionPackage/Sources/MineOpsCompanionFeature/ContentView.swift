import SwiftUI

enum V2RootTab: Hashable {
    case today
    case managers
    case strategy
    case more
}

public struct ContentView: View {
    @State private var progressService = SMProgressService.shared
    @State private var masterService = SMMasterDataService.shared
    @State private var hasInitialized = false
    @State private var selectedTab: V2RootTab = .today

    public init() {}

    public var body: some View {
        Group {
            if masterService.isLoading && !hasInitialized {
                loadingView
            } else {
                TabView(selection: $selectedTab) {
                    V2DashboardView(selectedTab: $selectedTab)
                        .tabItem {
                            Label("Today", systemImage: "sun.max.fill")
                        }
                        .tag(V2RootTab.today)

                    V2ManagersView()
                        .tabItem {
                            Label("Managers", systemImage: "person.text.rectangle")
                        }
                        .tag(V2RootTab.managers)

                    V2StrategyView()
                        .tabItem {
                            Label("Strategy", systemImage: "chart.bar.xaxis")
                        }
                        .tag(V2RootTab.strategy)

                    V2MoreView()
                        .tabItem {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                        .tag(V2RootTab.more)
                }
                .tint(.accentCyan)
                .preferredColorScheme(.light)
                .environment(progressService)
            }
        }
        .task {
            guard !hasInitialized else { return }
            hasInitialized = true

            // Load master data and progress and perform one launch-time sync if credentials exist
            await AppLaunchCoordinator.shared.initialize()
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
