import SwiftUI

struct StrategyPipelineView: View {
    @EnvironmentObject private var review: OCRReviewViewModel
    @StateObject private var pipeline = AIStrategyPipeline.shared
    
    // Persisted mine settings
    @State private var selectedMineType: MineType = MineSettingsStore.shared.selectedMineType
    @State private var mineNumber: Int = MineSettingsStore.shared.mineNumber(for: MineSettingsStore.shared.selectedMineType)
    @State private var selectedContinentMine: ContinentMine = .ruby
    @State private var prestige: Int = 0
    @State private var maxShaft: Int = 30
    
    @State private var notes = ""
    @State private var selectedManagerIDs: Set<String> = []

    @State private var showingSettings = false
    @State private var editingNumber: EditingNumber?
    
    private let settingsStore = MineSettingsStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MineOpsLayout.sectionSpacing) {
                    CollapsibleCardContainer(
                        title: "Mine Details",
                        titleColor: .accentCyan,
                        defaultExpanded: true,
                        accessibilityIdentifier: "mineDetailsCard"
                    ) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Mine Type Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Mine Type")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.7))
                                Picker("Mine Type", selection: $selectedMineType) {
                                    ForEach(MineType.allCases) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.accentCyan)
                                .accessibilityIdentifier("mineTypePicker")
                            }
                            
                            // Numbered progression mines (Mainland / Frontier)
                            if selectedMineType.usesNumberedProgression {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Mine Number")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.7))
                                    HStack(spacing: 16) {
                                        Button(action: { if mineNumber > 1 { mineNumber -= 1 } }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(Color.accentCyan)
                                                .font(.title2)
                                        }
                                        Button {
                                            editingNumber = .mineNumber
                                        } label: {
                                            Text("\(mineNumber)")
                                                .foregroundStyle(Color.white)
                                                .font(.title3.monospacedDigit())
                                                .frame(minWidth: 60)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Edit mine number")
                                        .accessibilityIdentifier("mineNumberValueButton")

                                        Button(action: { mineNumber += 1 }) {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundStyle(Color.accentCyan)
                                                .font(.title2)
                                        }
                                    }
                                    .accessibilityIdentifier("mineNumberStepper")
                                }
                            }
                            
                            // Continent: Mine type picker within that continent
                            if let continentMines = selectedMineType.continentMines {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Mine")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.7))
                                    Picker("Continent Mine", selection: $selectedContinentMine) {
                                        ForEach(continentMines) { mine in
                                            Text(mine.rawValue).tag(mine)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.accentCyan)
                                    .accessibilityIdentifier("continentMinePicker")
                                }
                                .onAppear {
                                    // Reset to first available mine if current selection not in list
                                    if !continentMines.contains(selectedContinentMine) {
                                        selectedContinentMine = continentMines.first ?? .ruby
                                    }
                                }
                            }
                            
                            // Prestige Level
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Prestige Level")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.7))
                                HStack(spacing: 16) {
                                    Button(action: { if prestige > 0 { prestige -= 1 } }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(Color.accentCyan)
                                            .font(.title2)
                                    }
                                    Button {
                                        editingNumber = .prestige
                                    } label: {
                                        Text("\(prestige)")
                                            .foregroundStyle(Color.white)
                                            .font(.title3.monospacedDigit())
                                            .frame(minWidth: 60)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Edit prestige level")
                                    .accessibilityIdentifier("prestigeValueButton")

                                    Button(action: { if prestige < 999 { prestige += 1 } }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(Color.accentCyan)
                                            .font(.title2)
                                    }
                                }
                                .accessibilityIdentifier("prestigeStepper")
                            }
                            
                            // Max Shaft Level
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Max Shaft Level")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.7))
                                HStack(spacing: 16) {
                                    Button(action: { if maxShaft > 1 { maxShaft -= 1 } }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(Color.accentCyan)
                                            .font(.title2)
                                    }
                                    Button {
                                        editingNumber = .maxShaft
                                    } label: {
                                        Text("\(maxShaft)")
                                            .foregroundStyle(Color.white)
                                            .font(.title3.monospacedDigit())
                                            .frame(minWidth: 60)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Edit max shaft level")
                                    .accessibilityIdentifier("maxShaftValueButton")

                                    Button(action: { if maxShaft < 999 { maxShaft += 1 } }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(Color.accentCyan)
                                            .font(.title2)
                                    }
                                }
                                .accessibilityIdentifier("maxShaftStepper")
                            }

                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("notesField")
                        }
                    }

                    MineOpsButton(label: pipeline.isAnalyzing ? "Analyzing…" : "Run AI Strategy", icon: "sparkles") {
                        Task {
                            let mineContext = MineContext(
                                type: selectedMineType,
                                mainlandMineNumber: selectedMineType.usesNumberedProgression ? mineNumber : nil,
                                continentMine: selectedMineType.continentMines != nil ? selectedContinentMine : nil,
                                prestige: prestige,
                                maxShaft: maxShaft
                            )
                            await pipeline.runFullPipeline(
                                mineContext: mineContext,
                                screenshots: [],
                                notes: notes.isEmpty ? nil : notes,
                                selectedRoster: selectedRecognizedManagers
                            )
                        }
                    }
                    .disabled(pipeline.isAnalyzing || selectedManagerIDs.isEmpty)
                    .accessibilityIdentifier("runStrategyButton")

                    CollapsibleCardContainer(
                        title: "Select Managers",
                        titleColor: .accentCyan,
                        defaultExpanded: false,
                        accessibilityIdentifier: "selectManagersCard"
                    ) {
                        if managerOptions.isEmpty {
                            Text("Import super managers on the Manager tab before running an AI strategy.")
                                .mineOpsBody()
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(managerOptions) { option in
                                    Button {
                                        toggleSelection(for: option.id)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: selectedManagerIDs.contains(option.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedManagerIDs.contains(option.id) ? Color.accentCyan : .white.opacity(0.4))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(option.name)
                                                    .mineOpsBody()
                                                    .foregroundStyle(.white)
                                                if let detail = option.detail {
                                                    Text(detail)
                                                        .font(.caption)
                                                        .foregroundStyle(.white.opacity(0.6))
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(Color.mineDarkLight.opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("managerSelection_\(option.id)")
                                }

                                HStack {
                                    Button("Select All") {
                                        selectedManagerIDs = Set(managerOptions.map { $0.id })
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Clear") {
                                        selectedManagerIDs.removeAll()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }

                    if let error = pipeline.lastError {
                        CollapsibleCardContainer(title: "Error", titleColor: .accentCyan, defaultExpanded: true) {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let strategy = pipeline.lastStrategy {
                        CollapsibleCardContainer(title: strategy.comboName, titleColor: .accentCyan, defaultExpanded: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(strategy.strategySummary)
                                    .mineOpsBody()
                                    .foregroundStyle(Color.accentCyan)
                                if !strategy.recommendedManagers.isEmpty {
                                    Text("Managers: " + strategy.recommendedManagers.joined(separator: ", "))
                                        .font(.subheadline)
                                        .foregroundStyle(Color.accentCyan)
                                }
                                if let multiplier = strategy.estimatedMultiplier {
                                    Text(String(format: "Estimated Boost: %.2fx", multiplier))
                                        .font(.caption)
                                        .foregroundStyle(Color.accentCyan.opacity(0.7))
                                }
                            }
                        }
                        if let plan = strategy.detailedPlan, !plan.isEmpty {
                            CollapsibleCardContainer(title: "Tactical Plan", defaultExpanded: true) {
                                Text(plan)
                                    .mineOpsBody()
                                    .foregroundStyle(.white)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    if !pipeline.detectedManagers.isEmpty {
                        CollapsibleCardContainer(title: "Detected Managers", titleColor: .accentCyan, defaultExpanded: true) {
                            Text(pipeline.detectedManagers.joined(separator: ", "))
                                .font(.footnote)
                                .foregroundStyle(Color.accentCyan)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    NavigationLink("Strategy History") {
                        StrategyHistoryView()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("historyNavigationLink")

                    Button(role: .destructive) {
                        pipeline.clearAllCaches()
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("clearCacheButton")
                }
                .padding(.horizontal, MineOpsLayout.cardPadding)
                .padding(.top, 8)
                .padding(.bottom, MineOpsLayout.cardPadding)
            }
            .navigationTitle("")
            .background(Color.mineDark.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.2.fill")
                            .foregroundStyle(Color.accentCyan)
                    }
                    .accessibilityLabel("Open settings")
                    .accessibilityIdentifier("openSettingsButton")
                }
                ToolbarItem(placement: .principal) {
                    Text("AI Strategy")
                        .font(.title.bold())
                        .foregroundStyle(Color.accentCyan)
                        .accessibilityIdentifier("aiStrategyHeader")
                }
            }
            .sheet(isPresented: $showingSettings) {
                MineOpsSettingsView()
            }
            .task { seedSelectionIfNeeded() }
            .onChange(of: review.recognized) { _, _ in seedSelectionIfNeeded() }
            // Persist mine type selection
            .onChange(of: selectedMineType) { _, newType in
                settingsStore.selectedMineType = newType

                if newType.usesNumberedProgression {
                    mineNumber = settingsStore.mineNumber(for: newType)
                }
                // Load stored continent mine for this mine type if applicable
                if let mines = newType.continentMines {
                    selectedContinentMine = settingsStore.selectedContinentMine(for: newType)
                    // Validate it's in the available list
                    if !mines.contains(selectedContinentMine) {
                        selectedContinentMine = mines.first ?? .ruby
                    }
                }
                // Load prestige and maxShaft for this mine type
                loadSettingsForCurrentMine()
            }
            // Persist individual settings
            .onChange(of: mineNumber) { _, newValue in
                guard selectedMineType.usesNumberedProgression else { return }
                settingsStore.setMineNumber(newValue, for: selectedMineType)
            }
            .onChange(of: selectedContinentMine) { _, newValue in
                settingsStore.setSelectedContinentMine(newValue, for: selectedMineType)
                // Reload settings for the new continent mine
                loadSettingsForCurrentMine()
            }
            .onChange(of: prestige) { _, newValue in
                saveCurrentMineSettings()
            }
            .onChange(of: maxShaft) { _, newValue in
                saveCurrentMineSettings()
            }
            .onAppear {
                // Load stored continent mine for current type
                if selectedMineType.continentMines != nil {
                    selectedContinentMine = settingsStore.selectedContinentMine(for: selectedMineType)
                }
                if selectedMineType.usesNumberedProgression {
                    mineNumber = settingsStore.mineNumber(for: selectedMineType)
                }
                loadSettingsForCurrentMine()
            }
            .sheet(item: $editingNumber) { item in
                NumberEntrySheet(
                    title: item.title,
                    currentValue: {
                        switch item {
                        case .mineNumber: return mineNumber
                        case .prestige: return prestige
                        case .maxShaft: return maxShaft
                        }
                    }(),
                    range: item.allowedRange,
                    accessibilityIdentifier: item.accessibilityIdentifier
                ) { newValue in
                    switch item {
                    case .mineNumber:
                        mineNumber = newValue
                    case .prestige:
                        prestige = newValue
                    case .maxShaft:
                        maxShaft = newValue
                    }
                }
            }
        }
    }
    
    /// The continent mine to use for storage, if applicable
    private var currentContinentMine: ContinentMine? {
        selectedMineType.continentMines != nil ? selectedContinentMine : nil
    }
    
    /// Loads prestige and maxShaft for the current mine configuration
    private func loadSettingsForCurrentMine() {
        prestige = settingsStore.prestige(for: selectedMineType, continentMine: currentContinentMine)
        maxShaft = settingsStore.maxShaft(for: selectedMineType, continentMine: currentContinentMine)
    }
    
    /// Saves prestige and maxShaft for the current mine configuration
    private func saveCurrentMineSettings() {
        settingsStore.setPrestige(prestige, for: selectedMineType, continentMine: currentContinentMine)
        settingsStore.setMaxShaft(maxShaft, for: selectedMineType, continentMine: currentContinentMine)
    }

    private func seedSelectionIfNeeded() {
        let valid = Set(managerOptions.map { $0.id })
        selectedManagerIDs = selectedManagerIDs.intersection(valid)
        if selectedManagerIDs.isEmpty {
            selectedManagerIDs = valid
        }
    }

    private func toggleSelection(for id: String) {
        if selectedManagerIDs.contains(id) {
            selectedManagerIDs.remove(id)
        } else {
            selectedManagerIDs.insert(id)
        }
    }
}

private extension StrategyPipelineView {
    enum EditingNumber: Identifiable {
        case mineNumber
        case prestige
        case maxShaft

        var id: String { String(describing: self) }

        var title: String {
            switch self {
            case .mineNumber: return "Mine Number"
            case .prestige: return "Prestige Level"
            case .maxShaft: return "Max Shaft Level"
            }
        }

        var allowedRange: ClosedRange<Int> {
            switch self {
            case .mineNumber: return 1...999
            case .prestige: return 0...999
            case .maxShaft: return 1...999
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .mineNumber: return "mineNumberEntry"
            case .prestige: return "prestigeEntry"
            case .maxShaft: return "maxShaftEntry"
            }
        }
    }
}

private extension StrategyPipelineView {
    struct ManagerOption: Identifiable {
        let id: String
        let name: String
        let detail: String?
    }

    var managerOptions: [ManagerOption] {
        var seen = Set<String>()
        return review.recognized.compactMap { sm in
            let identifier = sm.directoryMatch?.id ?? sm.resolvedName
            guard seen.insert(identifier).inserted else { return nil }
            let role: String?
            if let explicitRole = sm.role, !explicitRole.isEmpty {
                role = explicitRole
            } else if let department = sm.directoryMatch?.department {
                role = department.capitalized
            } else {
                role = nil
            }
            return ManagerOption(id: identifier, name: sm.resolvedName, detail: role)
        }
        .sorted { $0.name < $1.name }
    }

    var selectedManagerNames: [String] {
        managerOptions
            .filter { selectedManagerIDs.contains($0.id) }
            .map { $0.name }
    }

    var selectedRecognizedManagers: [RecognizedSM] {
        let ids = selectedManagerIDs
        return review.recognized
            .filter {
                // Use the same identifier logic as managerOptions to avoid mismatch.
                let identifier = $0.directoryMatch?.id ?? $0.resolvedName
                return ids.contains(identifier)
            }
            .sorted { $0.resolvedName.localizedCaseInsensitiveCompare($1.resolvedName) == .orderedAscending }
    }
}
