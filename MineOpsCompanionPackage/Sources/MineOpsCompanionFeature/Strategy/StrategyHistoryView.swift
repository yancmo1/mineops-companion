import CoreData
import SwiftUI

struct StrategyHistoryView: View {
    @State private var entries: [HistoryItem] = []
    @State private var selectedStrategy: HistoryItem?

    var body: some View {
        List {
            ForEach(entries) { item in
                Button {
                    selectedStrategy = item
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        if let comboName = item.comboName, !comboName.isEmpty {
                            Text(comboName)
                                .font(.headline)
                                .foregroundStyle(Color.accentCyan)
                        }
                        Text(item.mineName)
                            .font(.subheadline)
                            .foregroundStyle(Color.white)
                        Text("Prestige \(item.mineLevel) · Shaft \(item.shaftLevel)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        if !item.managers.isEmpty {
                            Text(item.managers.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Text(item.timestamp, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .navigationTitle("Strategy History")
        .toolbar { EditButton() }
        .sheet(item: $selectedStrategy) { item in
            StrategyDetailSheet(item: item)
        }
        .task { await loadHistory() }
    }

    @MainActor
    private func loadHistory() async {
        let context = CoreDataManager.shared.container.viewContext
        let request = NSFetchRequest<CachedStrategyEntity>(entityName: "CachedStrategy")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedStrategyEntity.timestamp, ascending: false)]
        if let results = try? context.fetch(request) {
            entries = results.compactMap { entity in
                guard let mineName = entity.mineName,
                      let timestamp = entity.timestamp else {
                    return nil
                }
                return HistoryItem(
                    id: entity.objectID,
                    mineName: mineName,
                    mineLevel: Int(entity.mineLevel),
                    shaftLevel: Int(entity.shaftLevel),
                    managers: entity.detectedManagers ?? [],
                    comboName: entity.comboName,
                    strategyJSON: entity.strategyJSON,
                    detailedPlan: entity.detailedPlan,
                    timestamp: timestamp
                )
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let context = CoreDataManager.shared.container.viewContext
        for index in offsets {
            let item = entries[index]
            if let object = try? context.existingObject(with: item.id) {
                context.delete(object)
            }
        }
        CoreDataManager.shared.saveContext()
        entries.remove(atOffsets: offsets)
    }
}

private struct HistoryItem: Identifiable, Hashable {
    let id: NSManagedObjectID
    let mineName: String
    let mineLevel: Int
    let shaftLevel: Int
    let managers: [String]
    let comboName: String?
    let strategyJSON: String?
    let detailedPlan: String?
    let timestamp: Date
}

private struct StrategyDetailSheet: View {
    let item: HistoryItem
    @Environment(\.dismiss) private var dismiss
    
    private var strategy: StrategyResponse? {
        guard let json = item.strategyJSON,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(StrategyResponse.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        if let comboName = item.comboName {
                            Text(comboName)
                                .font(.title2.bold())
                                .foregroundStyle(Color.accentCyan)
                        }
                        Text(item.mineName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Prestige \(item.mineLevel) · Max Shaft \(item.shaftLevel)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(item.timestamp, style: .date)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.mineDarkLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Summary
                    if let strategy = strategy {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summary")
                                .font(.headline)
                                .foregroundStyle(Color.accentCyan)
                            Text(strategy.strategySummary)
                                .font(.body)
                                .foregroundStyle(.white)
                            if let multiplier = strategy.estimatedMultiplier {
                                Text(String(format: "Estimated Boost: %.2fx", multiplier))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.accentCyan.opacity(0.8))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.mineDarkLight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Managers
                    if !item.managers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Managers")
                                .font(.headline)
                                .foregroundStyle(Color.accentCyan)
                            Text(item.managers.joined(separator: ", "))
                                .font(.body)
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.mineDarkLight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Detailed Plan
                    if let plan = item.detailedPlan, !plan.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tactical Plan")
                                .font(.headline)
                                .foregroundStyle(Color.accentCyan)
                            Text(plan)
                                .font(.body)
                                .foregroundStyle(.white)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.mineDarkLight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color.mineDark.ignoresSafeArea())
            .navigationTitle("Strategy Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
