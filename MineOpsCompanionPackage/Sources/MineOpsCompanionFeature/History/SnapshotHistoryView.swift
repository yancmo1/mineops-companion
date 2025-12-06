import SwiftUI

public struct SnapshotHistoryView: View {
  @State private var snapshots: [ImportSnapshot] = []
  @State private var showDeleteConfirmation = false
  @State private var snapshotToDelete: ImportSnapshot?
  
  public init() {}
  
  public var body: some View {
    VStack(spacing: 16) {
      if snapshots.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "clock.arrow.circlepath")
            .font(.system(size: 48))
            .foregroundStyle(Color.accentCyan.opacity(0.6))
          Text("No import history yet")
            .mineOpsCardTitle()
          Text("Snapshots are created each time you import screenshots")
            .mineOpsCaption()
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
      } else {
        ScrollView {
          VStack(spacing: 12) {
            ForEach(snapshots) { snapshot in
              SnapshotCard(snapshot: snapshot) {
                snapshotToDelete = snapshot
                showDeleteConfirmation = true
              }
            }
          }
          .padding()
        }
      }
    }
    .background(Color.mineDark.ignoresSafeArea())
    .navigationTitle("Import History")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !snapshots.isEmpty {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Task {
              await SnapshotManager.shared.clearAll()
              loadSnapshots()
            }
          } label: {
            Text("Clear All")
              .foregroundStyle(.red)
          }
        }
      }
    }
    .confirmationDialog(
      "Delete this snapshot?",
      isPresented: $showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        if let snapshot = snapshotToDelete {
          Task {
            await SnapshotManager.shared.deleteSnapshot(snapshot)
            loadSnapshots()
          }
        }
      }
      Button("Cancel", role: .cancel) {}
    }
    .task {
      loadSnapshots()
    }
  }
  
  private func loadSnapshots() {
    Task {
      snapshots = await SnapshotManager.shared.getAllSnapshots()
    }
  }
}

private struct SnapshotCard: View {
  let snapshot: ImportSnapshot
  let onDelete: () -> Void
  
  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(formattedDate(snapshot.timestamp))
            .mineOpsCardTitle()
          Spacer()
          Button {
            onDelete()
          } label: {
            Image(systemName: "trash")
              .foregroundStyle(.red.opacity(0.8))
          }
        }
        
        Text("\(snapshot.totalManagers) managers")
          .mineOpsBody()
          .foregroundStyle(.white.opacity(0.7))
        
        if !snapshot.byRarity.isEmpty {
          Divider()
            .overlay(Color.mineDarkLight.opacity(0.5))
            .padding(.vertical, 4)
          
          Text("By Rarity")
            .mineOpsCaption()
            .foregroundStyle(Color.accentCyan)
          
          ForEach(snapshot.byRarity.sorted(by: { $0.key < $1.key }), id: \.key) { rarity, count in
            HStack {
              Text(rarity)
                .mineOpsBody()
              Spacer()
              Text("\(count)")
                .mineOpsBody()
                .foregroundStyle(.white.opacity(0.7))
            }
          }
        }
        
        if !snapshot.byDepartment.isEmpty {
          Divider()
            .overlay(Color.mineDarkLight.opacity(0.5))
            .padding(.vertical, 4)
          
          Text("By Department")
            .mineOpsCaption()
            .foregroundStyle(Color.accentCyan)
          
          ForEach(snapshot.byDepartment.sorted(by: { $0.key < $1.key }), id: \.key) { dept, count in
            HStack {
              Text(dept)
                .mineOpsBody()
              Spacer()
              Text("\(count)")
                .mineOpsBody()
                .foregroundStyle(.white.opacity(0.7))
            }
          }
        }
      }
    }
  }
  
  private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}
