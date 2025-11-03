import CoreData
import SwiftUI

struct StrategyHistoryView: View {
    @State private var entries: [HistoryItem] = []

    var body: some View {
        List {
            ForEach(entries) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.mineName)
                        .font(.headline)
                    Text("Mine L\(item.mineLevel) · Shaft L\(item.shaftLevel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !item.managers.isEmpty {
                        Text(item.managers.joined(separator: ", "))
                            .font(.footnote)
                    }
                    Text(item.timestamp, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .navigationTitle("Strategy History")
        .toolbar { EditButton() }
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
    let timestamp: Date
}
