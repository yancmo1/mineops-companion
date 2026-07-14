import SwiftUI

struct V2MoreView: View {
    @State private var syncService = KolibriSyncService.shared
    @State private var metadataStore = SyncMetadataStore.shared
    @State private var isSyncing = false
    @State private var exportItem: ExportItem?
    @State private var showingExportError = false
    @State private var exportErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Game Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        statusBadge
                    }

                    if let playerName = metadataStore.metadata.playerName, !playerName.isEmpty {
                        infoRow("Player", playerName)
                    }

                    if let maskedID = metadataStore.metadata.maskedPlayerID, !maskedID.isEmpty {
                        infoRow("Player ID", maskedID)
                    }

                    if let lastSave = metadataStore.metadata.lastGameSaveDisplay {
                        infoRow("Game Save", lastSave)
                    }

                    if let lastSync = metadataStore.metadata.lastSuccessfulSyncAt {
                        HStack {
                            Text("MineOps Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let importedCount = metadataStore.metadata.importedManagerCount {
                        infoRow("Imported Managers", "\(importedCount)")
                    }

                    Button {
                        Task { await runSyncNow() }
                    } label: {
                        Label(isSyncing ? "Syncing…" : "Sync Now", systemImage: "arrow.clockwise")
                    }
                    .disabled(isSyncing || syncService.syncState == .syncing)
                    .accessibilityIdentifier("more_syncNow")

                    NavigationLink {
                        MineOpsSettingsView()
                    } label: {
                        Label("Game Connection Settings", systemImage: "link")
                    }
                    .accessibilityIdentifier("more_gameConnectionSettings")

                    NavigationLink {
                        KolibriSyncView()
                    } label: {
                        Label("Sync Diagnostics", systemImage: "ladybug")
                    }
                    .accessibilityIdentifier("more_syncDiagnostics")
                }

                Section("Sync Preferences") {
                    HStack {
                        Text("Sync on App Open")
                        Spacer()
                        Text("On")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Refresh Frequency")
                        Spacer()
                        Picker("Refresh Frequency", selection: $syncService.syncFrequency) {
                            ForEach(SyncFrequency.allCases) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Strategy & AI") {
                    NavigationLink {
                        MineOpsSettingsView()
                    } label: {
                        Label("AI Provider & Keys", systemImage: "sparkles")
                    }
                    .accessibilityIdentifier("more_aiSettings")
                }

                Section("Data") {
                    NavigationLink {
                        MineOpsSettingsView()
                    } label: {
                        Label("Data & Reset", systemImage: "externaldrive")
                    }
                    .accessibilityIdentifier("more_dataSettings")

                    Button {
                        Task { await exportSMTrackerBackup() }
                    } label: {
                        Label("Export SM Tracker Backup", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("more_exportSMBackup")
                    .sheet(item: $exportItem) { item in
                        ActivityView(activityItems: [item.url])
                    }
                    .alert("Export failed", isPresented: $showingExportError, actions: {
                        Button("OK", role: .cancel) {}
                    }, message: {
                        Text(exportErrorMessage ?? "Unknown error")
                    })
                }

                Section("About") {
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
            }
            .navigationTitle("More")
        }
    }

    private var statusBadge: some View {
        Group {
            switch syncService.syncState {
            case .idle:
                Label("Idle", systemImage: "circle")
                    .foregroundStyle(.secondary)
            case .syncing:
                Label("Syncing", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
            case .success:
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .error:
                Label("Needs Attention", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    @MainActor
    private func runSyncNow() async {
        isSyncing = true
        defer { isSyncing = false }
        await syncService.syncAndApplyToProgress()
    }

    // MARK: - Export

    private struct ExportEntry: Codable {
        let unlocked: Bool
        let rank: Int
        let level: Int
        let promoted: Int
        let fragments: Int
        let chronoExcluded: Bool
        let tierlistExcluded: Bool
    }

    private struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    @MainActor
    private func exportSMTrackerBackup() async {
        let progress = SMProgressService.shared.progress

        var dict: [String: ExportEntry] = [:]

        // Start with the canonical key ordering used by the external tracker format
        for key in SMTrackerExporter.canonicalManagerKeys {
            dict[key] = ExportEntry(
                unlocked: false,
                rank: 0,
                level: 1,
                promoted: 0,
                fragments: 0,
                chronoExcluded: false,
                tierlistExcluded: false
            )
        }

        // Populate entries from progress (override defaults)
        for p in progress {
            let key = p.master.id
            if dict[key] != nil {
                dict[key] = ExportEntry(
                    unlocked: p.unlocked,
                    rank: p.rank,
                    level: p.level,
                    promoted: p.promoted,
                    fragments: p.fragments,
                    chronoExcluded: false,
                    tierlistExcluded: false
                )
            }
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(dict)

            // Timestamp the filename so exports are unique and easier to manage
            let formatter = DateFormatter()
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let ts = formatter.string(from: Date())
            let filename = "sm-tracker-backup-\(ts).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)

            exportItem = ExportItem(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
            showingExportError = true
        }
    }
}

// Simple wrapper to present UIActivityViewController from SwiftUI
fileprivate struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    V2MoreView()
}
