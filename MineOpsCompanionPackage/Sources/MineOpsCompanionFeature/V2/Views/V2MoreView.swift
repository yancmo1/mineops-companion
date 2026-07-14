import SwiftUI

struct V2MoreView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section("Game Connection") {
                    NavigationLink {
                        KolibriSyncView()
                    } label: {
                        Label("Kolibri Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityIdentifier("more_kolibriSync")

                    Button {
                        showSettings = true
                    } label: {
                        Label("Connect Debug ID", systemImage: "link")
                    }
                    .accessibilityIdentifier("more_connectDebugID")
                }

                Section("MineOps") {
                    NavigationLink {
                        MineOpsSettingsView()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    .accessibilityIdentifier("more_settings")

                    NavigationLink {
                        VStack {
                            Text("MineOps Companion")
                                .font(.title2)
                                .padding()
                            Text("Version info and credits go here.")
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    .accessibilityIdentifier("more_about")
                }

                Section("Support & Diagnostics") {
                    Button {
                        // placeholder: trigger debug upload
                    } label: {
                        Label("Send Debug Info", systemImage: "paperplane")
                    }
                    .accessibilityIdentifier("more_sendDebug")

                    Button {
                        // placeholder: open logs viewer
                    } label: {
                        Label("View Logs", systemImage: "doc.plaintext")
                    }
                    .accessibilityIdentifier("more_viewLogs")
                }
            }
            .navigationTitle("More")
            .sheet(isPresented: $showSettings) {
                MineOpsSettingsView()
            }
        }
    }
}

#Preview {
    V2MoreView()
}
