// # File: Sources/MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/App/KolibriSyncView.swift

import SwiftUI

struct KolibriSyncView: View {
    @State private var syncService = KolibriSyncService.shared
    @State private var showSettings = false
    @State private var isApplyingRoster = false
    private let masterService = SMMasterDataService.shared
    
    var body: some View {
        NavigationStack {
            List {
                syncStatusSection
                debugSection
                
                if syncService.currentSavegame != nil {
                    managersSection
                    minesSection
                    resourcesSection
                }
            }
            .navigationTitle("Kolibri Sync")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityIdentifier("kolibriSettingsButton")
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await runManualSync()
                        }
                    } label: {
                        if syncService.syncState == .syncing || isApplyingRoster {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(syncService.syncState == .syncing || isApplyingRoster)
                    .accessibilityIdentifier("kolibriSyncButton")
                }
            }
            .refreshable {
                await runManualSync()
            }
            .sheet(isPresented: $showSettings) {
                MineOpsSettingsView()
            }
        }
    }
    
    // MARK: - Sync Status Section
    
    private var syncStatusSection: some View {
        Section("Sync Status") {
            HStack {
                Text("Status")
                Spacer()
                syncStatusBadge
            }
            
            if let lastSync = syncService.lastSyncDate {
                HStack {
                    Text("Last Sync")
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Mode")
                Spacer()
                Text("Manual (default)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Launch Refresh")
                Spacer()
                Picker("Launch Refresh", selection: $syncService.syncFrequency) {
                    ForEach(SyncFrequency.allCases) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("syncFrequencyPicker")
            }

            if let importedCount = syncService.lastImportedManagerCount {
                HStack {
                    Text("Imported to Manager tab")
                    Spacer()
                    Text("\(importedCount)")
                        .foregroundStyle(.secondary)
                }
            }
            
            if case .error(let message) = syncService.syncState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)

                if let details = syncService.lastErrorDetails {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var debugSection: some View {
        Section("Sync Debug") {
            debugRow("Master Source", masterService.currentSource.rawValue)
            debugRow("Master Entries", "\(masterService.masterData.count)")

            if let diagnostics = syncService.lastDiagnostics {
                debugRow("HTTP Status", "\(diagnostics.statusCode)")
                debugRow("Payload Format", diagnostics.payloadFormat)
                debugRow("Raw Bytes", "\(diagnostics.rawPayloadBytes)")
                debugRow("Decoded JSON Bytes", "\(diagnostics.decodedPayloadBytes)")
                debugRow("Managers Parsed", "\(diagnostics.managerCount)")
                debugRow("Prefix Hex", diagnostics.payloadPrefixHex)
            } else {
                Text("Run a manual sync to populate diagnostics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func debugRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .font(.caption)
        }
    }
    
    @ViewBuilder
    private var syncStatusBadge: some View {
        switch syncService.syncState {
        case .idle:
            Label("Idle", systemImage: "circle")
                .foregroundStyle(.secondary)
        case .syncing:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing...")
            }
            .foregroundStyle(.blue)
        case .success:
            Label("Success", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error:
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
    
    // MARK: - Managers Section
    
    private var managersSection: some View {
        Section("Managers") {
            let managers = syncService.getManagers()
            
            if managers.isEmpty {
                Text("No managers found")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(managers) { manager in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resolvedName(for: manager))
                            .font(.headline)
                        
                        HStack {
                            if let rarity = manager.rarity {
                                Text(rarity)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let level = manager.level {
                                Text("Lvl \(level)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let promotion = manager.promotion {
                                Text("P\(promotion)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let fragments = manager.fragments, fragments > 0 {
                                Text("⬥ \(fragments)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        if let assigned = manager.assignedTo {
                            Text("Assigned to: \(assigned)")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Mines Section
    
    private var minesSection: some View {
        Section("Mines") {
            let mines = syncService.getMines()
            
            if mines.isEmpty {
                Text("No mines found")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(mines) { mine in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mine.name ?? "Unknown Mine")
                            .font(.headline)
                        
                        HStack {
                            if let type = mine.mineType {
                                Text(type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let level = mine.level {
                                Text("Lvl \(level)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let shafts = mine.shaftCount {
                            Text("Shafts: \(shafts)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Resources Section
    
    private var resourcesSection: some View {
        Section("Resources") {
            if let resources = syncService.getResources() {
                if let superCash = resources.superCash {
                    HStack {
                        Text("Super Cash")
                        Spacer()
                        Text("\(superCash)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let greenCash = resources.greenCash {
                    HStack {
                        Text("Green Cash")
                        Spacer()
                        Text("\(greenCash)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let eventKeys = resources.eventKeys {
                    HStack {
                        Text("Event Keys")
                        Spacer()
                        Text("\(eventKeys)")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No resource data")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    @MainActor
    private func runManualSync() async {
        isApplyingRoster = true
        defer { isApplyingRoster = false }

        await syncService.syncAndApplyToProgress()
    }

    /// Resolve a human-readable name for a manager from master data, falling back to the raw id.
    private func resolvedName(for manager: ManagerData) -> String {
        // Use name if already provided
        if let name = manager.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        // Look up by gameId (manager.id is the gameId as a string)
        if let gameId = Int(manager.id),
           let entry = masterService.entry(for: gameId) {
            return entry.name
        }
        // Look up by slug
        if let entry = masterService.entry(for: manager.id) {
            return entry.name
        }
        return "Manager #\(manager.id)"
    }
}

#Preview {
    KolibriSyncView()
}
