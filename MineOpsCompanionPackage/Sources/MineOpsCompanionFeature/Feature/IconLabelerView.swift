import SwiftUI

struct IconLabelerView: View {
    @State private var harvestEntries: [HarvestEntry] = []
    @State private var labels: [String: IconLabel] = [:] // filename -> label
    @State private var currentIndex = 0
    @State private var selectedCategory: IconLabel.Category = .passive
    @State private var selectedPassive: PassiveEffectType?
    @State private var selectedActive: ActiveEffectType?
    @State private var errorMessage: String?
    @State private var showingAlignmentMode = false
    @State private var adjustedEntry: HarvestEntry?
    @State private var imageRefreshTrigger = UUID()
    @State private var alignmentTransform = IconAlignmentTransform()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if harvestEntries.isEmpty {
                    ContentUnavailableView(
                        "No Icons to Label",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Import some manager screenshots to start harvesting icons")
                    )
                } else if currentIndex >= harvestEntries.count {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        
                        Text("All Icons Labeled!")
                            .mineOpsHeadingStyle()
                        
                        Text("Labeled \(labels.count) icon\(labels.count == 1 ? "" : "s")")
                            .mineOpsBody()
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            Button("Auto-Identify") {
                                autoIdentifyIcons()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Export Templates") {
                                exportTemplates()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentCyan)
                        }
                    }
                } else {
                    let entry = harvestEntries[currentIndex]
                    
                    VStack(spacing: 12) {
                        // Progress
                        Text("\(currentIndex + 1) of \(harvestEntries.count)")
                            .mineOpsCaption()
                            .foregroundStyle(.secondary)
                        
                        // Manager info
                        Text(entry.managerName)
                            .mineOpsHeadingStyle()
                        
                        HStack {
                            Text("Slot \(entry.slotIndex + 1)")
                            Text("•")
                            Text(entry.isUnlocked ? "✓ Unlocked" : "🔒 Locked")
                                .foregroundStyle(entry.isUnlocked ? .green : .secondary)
                        }
                        .mineOpsCaption()
                        // Icon preview
                        if let image = loadImage(filename: entry.filename) {
                            VStack(spacing: 8) {
                                Image(uiImage: image)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .padding(16)
                                    .background(Color.mineDarkLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .id(imageRefreshTrigger)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Button {
                                    showingAlignmentMode = true
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        Text("Adjust Alignment")
                                    }
                                    .font(.caption)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        // Effect category picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Effect Category")
                                .mineOpsBody()
                                .foregroundStyle(.secondary)
                            
                            Picker("Category", selection: $selectedCategory) {
                                Text("Passive").tag(IconLabel.Category.passive)
                                Text("Active").tag(IconLabel.Category.active)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedCategory) { _, newValue in
                                switch newValue {
                                case .passive:
                                    selectedActive = nil
                                case .active:
                                    selectedPassive = nil
                                }
                                errorMessage = nil
                            }
                        }
                        
                        if selectedCategory == .passive {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Passive Effect")
                                    .mineOpsBody()
                                    .foregroundStyle(.secondary)
                                
                                Picker("Passive Effect", selection: $selectedPassive) {
                                    Text("Select passive type...").tag(PassiveEffectType?.none)
                                    ForEach(EffectTypeLists.passiveTypes) { type in
                                        Text(type.displayName)
                                            .tag(Optional(type))
                                    }
                                }
                                .pickerStyle(.menu)
                                .mineOpsBody()
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Active Effect")
                                    .mineOpsBody()
                                    .foregroundStyle(.secondary)
                                
                                Picker("Active Effect", selection: $selectedActive) {
                                    Text("Select active type...").tag(ActiveEffectType?.none)
                                    ForEach(EffectTypeLists.activeTypes) { type in
                                        Text(type.displayName)
                                            .tag(Optional(type))
                                    }
                                }
                                .pickerStyle(.menu)
                                .mineOpsBody()
                            }
                        }
                        
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .mineOpsCaption()
                        }
                        
                        // Actions
                        HStack(spacing: 12) {
                            Button("Skip") {
                                skipCurrent()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Save Label") {
                                saveLabel()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentCyan)
                            .disabled(!isSelectionValid)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Icon Labeler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        exportTemplates()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(labels.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingAlignmentMode) {
            if currentIndex < harvestEntries.count {
                IconAlignmentView(
                    entry: harvestEntries[currentIndex],
                    initialTransform: alignmentTransform,
                    onSave: { adjustedEntry, transform in
                        self.adjustedEntry = adjustedEntry
                        alignmentTransform = transform
                        imageRefreshTrigger = UUID()
                        showingAlignmentMode = false
                    }
                )
            }
        }
        .onAppear {
            loadHarvest()
            loadLabels()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadHarvest() {
        guard let docsURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            print("❌ IconLabeler: Could not access Documents directory")
            return
        }
        
        let csvURL = docsURL
            .appendingPathComponent("Icons", isDirectory: true)
            .appendingPathComponent("_harvest.csv")
        
        print("📁 IconLabeler: Looking for harvest CSV at: \(csvURL.path)")
        
        guard FileManager.default.fileExists(atPath: csvURL.path) else {
            print("⚠️ IconLabeler: No harvest CSV found. Import screenshots first to harvest icons.")
            return
        }
        
        guard let csvContent = try? String(contentsOf: csvURL, encoding: .utf8) else {
            print("❌ IconLabeler: Could not read harvest CSV")
            return
        }
        
        print("✅ IconLabeler: Loaded harvest CSV with \(csvContent.components(separatedBy: .newlines).count - 1) entries")
        
        let lines = csvContent.components(separatedBy: .newlines).dropFirst() // skip header
        
        harvestEntries = lines.compactMap { line in
            guard !line.isEmpty else { return nil }
            let parts = parseCSVLine(line)
            guard parts.count >= 7 else { return nil }
            
            return HarvestEntry(
                filename: parts[0],
                managerId: parts[1],
                managerName: parts[2],
                slotIndex: Int(parts[3]) ?? 0,
                isUnlocked: parts[4].lowercased() == "true",
                confidence: Double(parts[5]) ?? 0,
                createdAt: parts[6]
            )
        }
        .filter { !labels.keys.contains($0.filename) } // Skip already labeled
    }
    
    private func loadLabels() {
        guard let docsURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        
        let labelsURL = docsURL
            .appendingPathComponent("Icons", isDirectory: true)
            .appendingPathComponent("_labels.json")
        
        guard let data = try? Data(contentsOf: labelsURL),
              let decoded = try? JSONDecoder().decode([IconLabel].self, from: data) else {
            return
        }
        
        labels = Dictionary(uniqueKeysWithValues: decoded.map { ($0.file, $0) })
    }
    
    private func loadImage(filename: String) -> UIImage? {
        guard let docsURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }
        
        let imageURL = docsURL
            .appendingPathComponent("Icons", isDirectory: true)
            .appendingPathComponent(filename)
        
        guard let data = try? Data(contentsOf: imageURL) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Actions
    
    private var isSelectionValid: Bool {
        switch selectedCategory {
        case .passive:
            return selectedPassive != nil
        case .active:
            return selectedActive != nil
        }
    }
    
    private func saveLabel() {
        guard currentIndex < harvestEntries.count else { return }
        
        let entry = harvestEntries[currentIndex]
        let label: IconLabel
        
        switch selectedCategory {
        case .passive:
            guard let passive = selectedPassive else {
                errorMessage = "Please select a passive effect"
                return
            }
            label = IconLabel(
                file: entry.filename,
                category: .passive,
                type: passive.rawValue,
                unlocked: entry.isUnlocked
            )
        case .active:
            guard let active = selectedActive else {
                errorMessage = "Please select an active effect"
                return
            }
            label = IconLabel(
                file: entry.filename,
                category: .active,
                type: active.rawValue,
                unlocked: entry.isUnlocked
            )
        }
        
        labels[entry.filename] = label
        
        // Save to JSON
        if saveLabelsToFile() {
            selectedPassive = nil
            selectedActive = nil
            errorMessage = nil
            currentIndex += 1
        } else {
            errorMessage = "Failed to save label"
        }
    }
    
    private func skipCurrent() {
        currentIndex += 1
        selectedPassive = nil
        selectedActive = nil
        errorMessage = nil
    }
    
    private func saveLabelsToFile() -> Bool {
        guard let docsURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return false }
        
        let iconsDir = docsURL.appendingPathComponent("Icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
        
        let labelsURL = iconsDir.appendingPathComponent("_labels.json")
        let labelArray = Array(labels.values)
        
        guard let data = try? JSONEncoder().encode(labelArray) else { return false }
        
        do {
            try data.write(to: labelsURL)
            return true
        } catch {
            return false
        }
    }
    
    private func autoIdentifyIcons() {
        Task { @MainActor in
            // Load templates
            let templates = IconTemplateMatcher.loadTemplates()
            guard !templates.isEmpty else {
                errorMessage = "No templates found. Label some icons and export first."
                return
            }
            
            var identified = 0
            let unlabeled = harvestEntries.filter { !labels.keys.contains($0.filename) }
            
            for entry in unlabeled {
                guard let iconImage = loadImage(filename: entry.filename) else { continue }
                
                // Try to match against templates
                if let match = IconTemplateMatcher.findBestMatch(for: iconImage, in: templates) {
                    let label = IconLabel(
                        file: entry.filename,
                        category: .passive,
                        type: match.type,
                        unlocked: entry.isUnlocked
                    )
                    labels[entry.filename] = label
                    identified += 1
                    print("🔍 Auto-identified \(entry.filename) as \(match.type) (similarity: \(String(format: "%.2f", match.similarity)))")
                }
            }
            
            // Save updated labels
            if identified > 0 {
                _ = saveLabelsToFile()
                loadHarvest() // Refresh unlabeled list
                errorMessage = "✅ Auto-identified \(identified) icon\(identified == 1 ? "" : "s")"
            } else {
                errorMessage = "No new matches found"
            }
            
            print("✅ Auto-identified \(identified) icons")
        }
    }
    
    private func exportTemplates() {
        // Group labels by type, pick best unlocked for each
        var templatesByType: [String: IconLabel] = [:]
        
        for label in labels.values where label.category == .passive && label.unlocked && label.type != PassiveEffectType.skip.rawValue && label.type != PassiveEffectType.other.rawValue {
            if let existing = templatesByType[label.type] {
                // Keep the one with higher confidence (encoded in filename)
                if label.file > existing.file {
                    templatesByType[label.type] = label
                }
            } else {
                templatesByType[label.type] = label
            }
        }
        
        guard !templatesByType.isEmpty else {
            errorMessage = "No valid templates to export"
            return
        }
        
        Task {
            do {
                guard let docsURL = try? FileManager.default.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                ) else { return }
                
                let templatesDir = docsURL
                    .appendingPathComponent("Icons/templates", isDirectory: true)
                
                try FileManager.default.createDirectory(at: templatesDir, withIntermediateDirectories: true)
                
                // Copy chosen PNGs to templates directory
                for (type, label) in templatesByType {
                    let sourceURL = docsURL
                        .appendingPathComponent("Icons")
                        .appendingPathComponent(label.file)
                    
                    let destURL = templatesDir
                        .appendingPathComponent("\(type).png")
                    
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                }
                
                await MainActor.run {
                    errorMessage = "✅ Exported \(templatesByType.count) template\(templatesByType.count == 1 ? "" : "s")"
                }
                
                print("✅ Exported \(templatesByType.count) templates to \(templatesDir.path)")
            } catch {
                await MainActor.run {
                    errorMessage = "❌ Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - CSV Parsing
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            result.append(current)
        }
        
        return result
    }
}

// MARK: - Models

struct HarvestEntry: Identifiable {
    let id = UUID()
    let filename: String
    let managerId: String
    let managerName: String
    let slotIndex: Int
    let isUnlocked: Bool
    let confidence: Double
    let createdAt: String
}

struct IconLabel: Codable {
    enum Category: String, Codable, CaseIterable {
        case passive
        case active
    }
    
    let file: String
    let category: Category
    let type: String
    let unlocked: Bool
    
    init(file: String, category: Category = .passive, type: String, unlocked: Bool) {
        self.file = file
        self.category = category
        self.type = type
        self.unlocked = unlocked
    }
    
    private enum CodingKeys: String, CodingKey {
        case file
        case category
        case type
        case unlocked
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        file = try container.decode(String.self, forKey: .file)
        type = try container.decode(String.self, forKey: .type)
        unlocked = try container.decode(Bool.self, forKey: .unlocked)
        category = try container.decodeIfPresent(Category.self, forKey: .category) ?? .passive
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(file, forKey: .file)
        try container.encode(category, forKey: .category)
        try container.encode(type, forKey: .type)
        try container.encode(unlocked, forKey: .unlocked)
    }
}
