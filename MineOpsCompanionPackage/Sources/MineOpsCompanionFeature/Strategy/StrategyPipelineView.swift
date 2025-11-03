import PhotosUI
import SwiftUI
import UIKit

struct StrategyPipelineView: View {
    @EnvironmentObject private var review: OCRReviewViewModel
    @StateObject private var pipeline = AIStrategyPipeline.shared
    @State private var mineName = "Frontier Mine"
    @State private var mineLevel = 120
    @State private var shaftLevel = 25
    @State private var notes = ""
    @State private var screenshots: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedManagerIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MineOpsLayout.sectionSpacing) {
                    CardContainer(title: "Mine Details") {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Mine name", text: $mineName)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("mineNameField")

                            Stepper(value: $mineLevel, in: 1...999) {
                                Text("Mine Level: \(mineLevel)")
                            }
                            .accessibilityIdentifier("mineLevelStepper")

                            Stepper(value: $shaftLevel, in: 1...999) {
                                Text("Shaft Level: \(shaftLevel)")
                            }
                            .accessibilityIdentifier("shaftLevelStepper")

                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("notesField")
                        }
                    }

                    CardContainer(title: "Select Managers") {
                        if managerOptions.isEmpty {
                            Text("Import super managers on the Manager tab before running an AI strategy.")
                                .mineOpsBody()
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(managerOptions) { option in
                                    Button {
                                        toggleSelection(for: option.id)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: selectedManagerIDs.contains(option.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedManagerIDs.contains(option.id) ? Color.accentCyan : .secondary)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(option.name)
                                                    .mineOpsBody()
                                                if let detail = option.detail {
                                                    Text(detail)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
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

                    CardContainer(title: "Optional Screenshots") {
                        VStack(spacing: 12) {
                            PhotosPicker(
                                selection: $pickerItems,
                                maxSelectionCount: 6,
                                matching: .images
                            ) {
                                Label("Add Screenshots", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("addScreenshotButton")
                            .onChange(of: pickerItems) { _, newItems in
                                Task { await loadImages(from: newItems) }
                            }

                            if screenshots.isEmpty {
                                Text("Optional: Add screenshots to auto-detect managers.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Loaded \(screenshots.count) screenshot(s)")
                                        .font(.subheadline)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(Array(screenshots.enumerated()), id: \.offset) { index, image in
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay(alignment: .topTrailing) {
                                                        Button {
                                                            screenshots.remove(at: index)
                                                        } label: {
                                                            Image(systemName: "xmark.circle.fill")
                                                                .symbolRenderingMode(.hierarchical)
                                                                .foregroundStyle(.white, .red)
                                                        }
                                                        .offset(x: 6, y: -6)
                                                        .accessibilityIdentifier("removeScreenshotButton_\(index)")
                                                    }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MineOpsButton(label: pipeline.isAnalyzing ? "Analyzing…" : "Run AI Strategy", icon: "sparkles") {
                        Task {
                            await pipeline.runFullPipeline(
                                mineName: mineName,
                                mineLevel: mineLevel,
                                shaftLevel: shaftLevel,
                                screenshots: screenshots,
                                notes: notes.isEmpty ? nil : notes,
                                selectedManagers: selectedManagerNames
                            )
                        }
                    }
                    .disabled(pipeline.isAnalyzing || (selectedManagerIDs.isEmpty && screenshots.isEmpty))
                    .accessibilityIdentifier("runStrategyButton")

                    if let error = pipeline.lastError {
                        CardContainer(title: "Error") {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let strategy = pipeline.lastStrategy {
                        CardContainer(title: strategy.comboName) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(strategy.strategySummary)
                                    .mineOpsBody()
                                if !strategy.recommendedManagers.isEmpty {
                                    Text("Managers: " + strategy.recommendedManagers.joined(separator: ", "))
                                        .font(.subheadline)
                                }
                                if let multiplier = strategy.estimatedMultiplier {
                                    Text(String(format: "Estimated Boost: %.2fx", multiplier))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !pipeline.detectedManagers.isEmpty {
                        CardContainer(title: "Detected Managers") {
                            Text(pipeline.detectedManagers.joined(separator: ", "))
                                .font(.footnote)
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
                .padding(MineOpsLayout.cardPadding)
            }
            .navigationTitle("AI Strategy")
            .background(Color.mineDark.ignoresSafeArea())
            .task { seedSelectionIfNeeded() }
            .onChange(of: review.recognized) { _, _ in seedSelectionIfNeeded() }
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loaded.append(image)
                }
            } catch {
                continue
            }
        }
        await MainActor.run {
            screenshots.append(contentsOf: loaded)
        }
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
}
