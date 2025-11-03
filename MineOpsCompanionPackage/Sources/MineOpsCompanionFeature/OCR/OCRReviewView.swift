import PhotosUI
import SwiftUI
import UIKit

struct OCRReviewView: View {
    @EnvironmentObject private var review: OCRReviewViewModel
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var importError: String?
    @State private var progressMessage: String?
    @StateObject private var ocr = OCRProcessor()
    @State private var isEditingManager = false
    @State private var editingRecord: RecognizedSM?
    @State private var editDraft = RecognizedSMEditDraft()
    @State private var expandedCardIds = Set<UUID>()
    @State private var showingScreenshotImporter = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Pick Images")
                            .font(.headline)
                    }
                    .foregroundStyle(Color.accentCyan)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.mineDarkLight)
                    .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius)
                            .stroke(Color.accentCyan.opacity(0.7), lineWidth: 1)
                    )
                }
                .photosPickerAccessoryVisibility(.visible)
                .onChange(of: selectedPhotos, initial: false) { _, _ in
                    Task { @MainActor in await importSelected() }
                }
                .accessibilityIdentifier("selectScreenshotsButton")
                
                Button {
                    showingScreenshotImporter = true
                } label: {
                    HStack {
                        Image(systemName: "photo.stack")
                        Text("Import New")
                            .font(.headline)
                    }
                    .foregroundStyle(Color.accentCyan)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.mineDarkLight)
                    .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius)
                            .stroke(Color.accentCyan.opacity(0.7), lineWidth: 1)
                    )
                }
                .sheet(isPresented: $showingScreenshotImporter) {
                    ScreenshotImporterView()
                }
                .accessibilityIdentifier("importScreenshotsButton")
            }

            if let progressMessage {
                Text(progressMessage)
                    .mineOpsCaption()
                    .accessibilityIdentifier("importProgressLabel")
            }

            if let importError {
                Text(importError)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("importErrorLabel")
            }

            if review.recognized.isEmpty {
                Text("No super managers recognized yet. Import screenshots to get started.")
                    .mineOpsCaption()
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            List {
                ForEach(review.recognized) { result in
                    let isExpanded = expandedCardIds.contains(result.id)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.directoryMatch?.name ?? result.resolvedName)
                            .mineOpsCardTitle()

                        if let rarityLine = rarityLine(for: result) {
                            Text(rarityLine)
                                .mineOpsBody()
                                .foregroundStyle(.secondary)
                        }

                        Text("Assignment: \(assignmentLine(for: result))")
                            .mineOpsBody()
                            .foregroundStyle(.secondary)

                        Text("Promotion: \(promotionText(for: result))")
                            .mineOpsBody()
                            .foregroundStyle(.secondary)

                        if let levelLine = levelLine(for: result) {
                            Text(levelLine)
                                .mineOpsBody()
                                .foregroundStyle(.secondary)
                        }

                        if let activeLine = activeLine(for: result) {
                            Text(activeLine)
                                .mineOpsBody()
                                .foregroundStyle(.secondary)
                        }

                        if let passiveLine = passiveLine(for: result) {
                            Text(passiveLine)
                                .mineOpsBody()
                                .foregroundStyle(.secondary)
                        }

                        if isExpanded {
                            if result.actions.hasLevelUp || result.actions.hasPromote || result.actions.hasRankUp {
                                Text(actionFlagsLine(for: result.actions))
                                    .mineOpsCaption()
                                    .foregroundStyle(Color.accentCyan)
                            }

                            if !debugPairs(for: result).isEmpty {
                                Divider()
                                    .overlay(Color.mineDarkLight.opacity(0.5))
                                    .padding(.vertical, 2)

                                ForEach(Array(debugPairs(for: result).enumerated()), id: \.offset) { _, field in
                                    HStack {
                                        Text(field.label)
                                            .mineOpsCaption()
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(field.value)
                                            .mineOpsCaption()
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                        
                        if !isExpanded {
                            HStack {
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Tap to expand")
                                    .mineOpsCaption()
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.mineDarkCard)
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedCardIds.contains(result.id) {
                                expandedCardIds.remove(result.id)
                            } else {
                                expandedCardIds.insert(result.id)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", role: .destructive) {
                            review.delete(result)
                        }
                        Button("Edit") {
                            editingRecord = result
                            editDraft = RecognizedSMEditDraft(record: result)
                            isEditingManager = true
                            expandedCardIds.remove(result.id)
                        }
                        .tint(.accentCyan)
                    }
                    .accessibilityIdentifier("ocrResultRow_\(result.id.uuidString)")
                }
                .onDelete(perform: deleteManagers)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .overlay { if isImporting { ProgressView().progressViewStyle(.circular) } }
        }
        .padding()
        .background(Color.mineDark.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(Color.accentCyan)
                    .accessibilityHidden(true)
            }
            ToolbarItem(placement: .principal) {
                Text("Manager")
                    .font(.headline)
                    .foregroundStyle(Color.accentCyan)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Menu {
                        NavigationLink {
                            IconCalibrationView()
                        } label: {
                            Label("Calibrate Icons", systemImage: "viewfinder.circle")
                        }
                        
                        NavigationLink {
                            IconLabelerView()
                        } label: {
                            Label("Label Icons", systemImage: "tag.fill")
                        }
                        
                        NavigationLink {
                            SnapshotHistoryView()
                        } label: {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.accentCyan)
                    }
                    
                    EditButton()
                        .tint(.accentCyan)
                    Image(systemName: "checkmark.seal")
                        .foregroundStyle(Color.accentCyan)
                        .accessibilityHidden(true)
                }
            }
        }
        .sheet(isPresented: $isEditingManager, onDismiss: {
            editingRecord = nil
        }) {
            NavigationStack {
                if let record = editingRecord {
                    ManagerEditSheet(
                        draft: $editDraft,
                        original: record,
                        onCancel: {
                            isEditingManager = false
                        },
                        onSave: { updated in
                            review.update(record, with: updated)
                            isEditingManager = false
                        },
                        onDelete: {
                            review.delete(record)
                            isEditingManager = false
                        }
                    )
                } else {
                    VStack {
                        Text("No manager selected")
                            .mineOpsBody()
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isEditingManager = false }
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Color.mineDark)
        }
        .onChange(of: ocr.results) { _, newValue in
            review.replace(with: newValue)
        }
    }

    @MainActor
    private func importSelected() async {
        guard !selectedPhotos.isEmpty else { return }
        isImporting = true
        importError = nil
        progressMessage = "Importing \(selectedPhotos.count) screenshot(s)…"

        ocr.reset()
        
        var skippedDuplicates = 0
        var processedImages: [(image: UIImage, result: RecognizedSM)] = []

        defer {
            isImporting = false
            
            if skippedDuplicates > 0 {
                progressMessage = "Skipped \(skippedDuplicates) duplicate(s)"
            } else {
                progressMessage = nil
            }
            
            review.replace(with: ocr.results)
            
            // Create snapshot after successful import
            if !ocr.results.isEmpty {
                let snapshot = ImportSnapshot.create(from: review.recognized)
                Task {
                    await SnapshotManager.shared.saveSnapshot(snapshot)
                }
            }
            
            selectedPhotos = []
        }

        for item in selectedPhotos {
            do {
                guard let data = try await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else {
                    throw ImportError.decodeFailed
                }
                
                // Check for duplicate using perceptual hash
                if let hash = ImageHasher.perceptualHash(for: img) {
                    if await ImageHashStore.shared.isDuplicate(hash) {
                        print("⏭️ Skipping duplicate image (hash: \(hash.prefix(8))...)")
                        skippedDuplicates += 1
                        continue
                    } else {
                        print("✅ New image (hash: \(hash.prefix(8))...)")
                    }
                    await ImageHashStore.shared.addHash(hash)
                }
                
                let resultsBefore = ocr.results.count
                await ocr.processImages([img])
                
                // Track which images were successfully processed
                if ocr.results.count > resultsBefore, let newResult = ocr.results.last {
                    processedImages.append((img, newResult))
                }
            } catch {
                importError = "Failed to import one or more screenshots."
            }
        }
        
        // Harvest icons for training/labeling
        if !processedImages.isEmpty {
            progressMessage = "Harvesting passive icons..."
            for (image, result) in processedImages {
                let managerId = result.id.uuidString
                let managerName = result.directoryMatch?.name ?? result.resolvedName
                
                print("🔍 Harvesting icons for \(managerName) (ID: \(managerId))")
                let icons = IconHarvester.harvestIcons(from: image, managerId: managerId)
                print("📦 Found \(icons.count) icons to harvest")
                
                if icons.isEmpty {
                    print("⚠️ No icons harvested for \(managerName) - check calibration or passive detection")
                } else {
                    do {
                        try IconHarvester.saveHarvest(icons, managerId: managerId, managerName: managerName, sourceImage: image)
                        print("✅ Saved \(icons.count) icons for \(managerName)")
                    } catch {
                        print("❌ Failed to save harvest for \(managerName): \(error)")
                    }
                }
            }
        }
    }
}

private enum ImportError: Error {
    case decodeFailed
}

private extension OCRReviewView {
    func deleteManagers(at offsets: IndexSet) {
        for index in offsets {
            guard review.recognized.indices.contains(index) else { continue }
            let record = review.recognized[index]
            review.delete(record)
        }
    }

    func rarityLine(for result: RecognizedSM) -> String? {
        let rarity = result.rarity ?? result.directoryMatch?.rarity.capitalized
        guard rarity != nil || result.stars != nil else { return nil }

        var parts: [String] = []
        if let rarity { parts.append(rarity) }
        if let stars = result.stars { parts.append("⭐️ x\(stars)") }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    func assignmentLine(for result: RecognizedSM) -> String {
        if let role = result.role {
            return role.capitalized
        }
        return result.departmentDisplay
    }

    func debugPairs(for result: RecognizedSM) -> [(label: String, value: String)] {
        [
            ("Rarity", valueOrDash(result.rarity)),
            ("Role", valueOrDash(result.role)),
            ("Stars", result.stars.map { String($0) } ?? "—"),
            ("Active Effect", valueOrDash(result.active.effect)),
            ("Active Multiplier", formatMultiplier(result.active.multiplier)),
            ("Active Duration", result.active.durationSeconds.map { formatDuration(seconds: $0) } ?? "—"),
            ("Active Cooldown", result.active.cooldownSeconds.map { formatDuration(seconds: $0) } ?? "—"),
            ("Passive Effect", valueOrDash(result.passive.effect)),
            ("Passive Multiplier", formatMultiplier(result.passive.multiplier)),
            ("Passive Duration", result.passive.durationSeconds.map { formatDuration(seconds: $0) } ?? "—"),
            ("Has Level Up", result.actions.hasLevelUp ? "Yes" : "No"),
            ("Has Promote", result.actions.hasPromote ? "Yes" : "No"),
            ("Has Rank Up", result.actions.hasRankUp ? "Yes" : "No")
        ]
    }

    func promotionText(for result: RecognizedSM) -> String {
        result.stats.promotionDisplay ?? "—"
    }

    func levelLine(for result: RecognizedSM) -> String? {
        if let display = result.stats.levelDisplay {
            return "Level: \(display)"
        }
        if let level = result.level {
            return "Level: \(level)"
        }
        return nil
    }

    func activeLine(for result: RecognizedSM) -> String? {
        var pieces: [String] = []
        if let effect = result.active.effect, !effect.isEmpty {
            pieces.append(effect)
        }
        if let multiplier = result.active.multiplier {
            pieces.append(formatPercent(fromMultiplier: multiplier))
        } else if let active = result.stats.activeMultiplierDisplay {
            pieces.append(active)
        } else if let fallback = result.directoryMatch?.active?.multiplier {
            pieces.append(formatPercent(fromMultiplier: fallback))
        }

        if let duration = result.active.durationSeconds {
            pieces.append("Duration: \(formatDuration(seconds: duration))")
        } else if let duration = result.stats.durationDisplays.first {
            pieces.append(duration)
        }

        if let cooldown = result.active.cooldownSeconds {
            pieces.append("Cooldown: \(formatDuration(seconds: cooldown))")
        }

        guard !pieces.isEmpty else { return nil }
        return "Active: " + pieces.joined(separator: " • ")
    }

    func passiveLine(for result: RecognizedSM) -> String? {
        var entries: [String] = []
        if let effect = result.passive.effect, !effect.isEmpty {
            entries.append(effect)
        }
        if let multiplier = result.passive.multiplier {
            entries.append(formatPercent(fromMultiplier: multiplier))
        }
        if let duration = result.passive.durationSeconds {
            entries.append("Duration: \(formatDuration(seconds: duration))")
        }

        if entries.isEmpty {
            if let passive = result.stats.secondaryBoostDisplay, !passive.isEmpty {
                entries.append(passive)
            } else {
                entries.append(contentsOf: result.stats.secondaryBoostTokens)
            }
        }
        entries = entries.flatMap { $0.split(separator: "•").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
        entries = entries.filter { !$0.isEmpty }
        
        // Add unlock status indicators
        let unlockIndicators = result.passive.unlockedSlots.map { $0 ? "✓" : "🔒" }.joined(separator: " ")
        let prefix = unlockIndicators.isEmpty ? "Passive:" : "Passive [\(unlockIndicators)]:"
        
        guard !entries.isEmpty else { return nil }
        return prefix + " " + entries.joined(separator: " • ")
    }

    func actionFlagsLine(for actions: RecognizedSM.ActionFlags) -> String {
        var labels: [String] = []
        if actions.hasLevelUp { labels.append("Level Up") }
        if actions.hasPromote { labels.append("Promote") }
        if actions.hasRankUp { labels.append("Rank Up") }
        return labels.joined(separator: " • ")
    }

    func valueOrDash(_ value: String?) -> String {
        guard let value else { return "—" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    func formatMultiplier(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value == floor(value) {
            return String(format: "%.0fx", value)
        }
        return String(format: "%.2fx", value)
    }

    func formatPercent(fromMultiplier multiplier: Double) -> String {
        let percent = (multiplier - 1) * 100
        if percent == 0 { return "0%" }
        if percent > 0 {
            return String(format: "+%.0f%%", percent.rounded())
        }
        return String(format: "%.0f%%", percent.rounded())
    }

    func formatDuration(seconds: Int) -> String {
        if seconds % 3600 == 0 {
            return "\(seconds / 3600)h"
        }
        if seconds >= 3600 {
            let hours = Double(seconds) / 3600.0
            return String(format: "%.1fh", hours)
        }
        if seconds % 60 == 0 {
            return "\(seconds / 60)m"
        }
        return "\(seconds)s"
    }
}

private struct RecognizedSMEditDraft {
    var resolvedName: String = ""
    var rarity: String = ""
    var role: String = ""
    var stars: String = ""
    var activeEffect: String = ""
    var activeMultiplier: String = ""
    var activeDuration: String = ""
    var activeCooldown: String = ""
    var passiveEffect: String = ""
    var passiveMultiplier: String = ""
    var passiveDuration: String = ""
    var hasLevelUp: Bool = false
    var hasPromote: Bool = false
    var hasRankUp: Bool = false

    init() {}

    init(record: RecognizedSM) {
        resolvedName = record.resolvedName
        rarity = record.rarity ?? ""
        role = record.role ?? ""
        stars = record.stars.map { String($0) } ?? ""
        activeEffect = record.active.effect ?? ""
        activeMultiplier = record.active.multiplier.map { Self.formatDouble($0) } ?? ""
        activeDuration = record.active.durationSeconds.map { Self.formatDurationForDraft($0) } ?? ""
        activeCooldown = record.active.cooldownSeconds.map { Self.formatDurationForDraft($0) } ?? ""
        passiveEffect = record.passive.effect ?? ""
        passiveMultiplier = record.passive.multiplier.map { Self.formatDouble($0) } ?? ""
        passiveDuration = record.passive.durationSeconds.map { Self.formatDurationForDraft($0) } ?? ""
        hasLevelUp = record.actions.hasLevelUp
        hasPromote = record.actions.hasPromote
        hasRankUp = record.actions.hasRankUp
    }

    func makeUpdatedRecord(from original: RecognizedSM) -> RecognizedSM {
        let resolved = cleaned(resolvedName) ?? original.resolvedName
        let rarityValue = cleaned(rarity)
        let roleValue = cleaned(role)
        let starsValue = parseStars(stars)

        let activeInfo = RecognizedSM.ActiveInfo(
            effect: cleaned(activeEffect),
            multiplier: parseMultiplier(activeMultiplier),
            durationSeconds: parseDuration(activeDuration),
            cooldownSeconds: parseDuration(activeCooldown)
        )

        let passiveInfo = RecognizedSM.PassiveInfo(
            effect: cleaned(passiveEffect),
            multiplier: parseMultiplier(passiveMultiplier),
            durationSeconds: parseDuration(passiveDuration)
        )

        let actionFlags = RecognizedSM.ActionFlags(
            hasLevelUp: hasLevelUp,
            hasPromote: hasPromote,
            hasRankUp: hasRankUp
        )

        return original.updatingMetadata(
            resolvedName: resolved,
            rarity: rarityValue,
            role: roleValue,
            stars: starsValue,
            active: activeInfo,
            passive: passiveInfo,
            actions: actionFlags
        )
    }

    private func cleaned(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseStars(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private func parseMultiplier(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let sanitized = trimmed
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "x", with: "", options: .caseInsensitive)
        return Double(sanitized)
    }

    private func parseDuration(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let regex = try? NSRegularExpression(pattern: #"^([0-9]{1,4})(?:\s*)([a-zA-Z]+)?$"#, options: .caseInsensitive) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                if let valueRange = Range(match.range(at: 1), in: trimmed),
                   let value = Int(trimmed[valueRange]) {
                    let unitRange = Range(match.range(at: 2), in: trimmed)
                    let unit = unitRange.map { String(trimmed[$0]).lowercased() } ?? "s"
                    return OCRFieldExtraction.durationToSeconds(value: value, unit: unit)
                }
            }
        }

        return Int(trimmed)
    }

    private static func formatDouble(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private static func formatDurationForDraft(_ seconds: Int) -> String {
        if seconds % 3600 == 0 {
            return "\(seconds / 3600)h"
        }
        if seconds >= 3600 {
            let hours = Double(seconds) / 3600.0
            return String(format: "%.1fh", hours)
        }
        if seconds % 60 == 0 {
            return "\(seconds / 60)m"
        }
        return "\(seconds)s"
    }
}

private struct ManagerEditSheet: View {
    @Binding var draft: RecognizedSMEditDraft
    let original: RecognizedSM
    let onCancel: () -> Void
    let onSave: (RecognizedSM) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Display Name", text: $draft.resolvedName)
                TextField("Rarity", text: $draft.rarity)
                TextField("Role", text: $draft.role)
                TextField("Stars", text: $draft.stars)
                    .keyboardType(.numberPad)
            }

            Section("Active Ability") {
                TextField("Effect", text: $draft.activeEffect)
                TextField("Multiplier (e.g. 6.42)", text: $draft.activeMultiplier)
                    .keyboardType(.decimalPad)
                TextField("Duration (e.g. 5m)", text: $draft.activeDuration)
                TextField("Cooldown (e.g. 30m)", text: $draft.activeCooldown)
            }

            Section("Passive Ability") {
                TextField("Effect", text: $draft.passiveEffect)
                TextField("Multiplier", text: $draft.passiveMultiplier)
                    .keyboardType(.decimalPad)
                TextField("Duration", text: $draft.passiveDuration)
            }

            Section("Actions") {
                Toggle("Level Up", isOn: $draft.hasLevelUp)
                Toggle("Promote", isOn: $draft.hasPromote)
                Toggle("Rank Up", isOn: $draft.hasRankUp)
            }

            Section {
                Button("Delete Manager", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.mineDark)
        .navigationTitle("Edit Manager")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let updated = draft.makeUpdatedRecord(from: original)
                    onSave(updated)
                    dismiss()
                }
                .tint(.accentCyan)
            }
        }
        .confirmationDialog(
            "Delete this manager?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
