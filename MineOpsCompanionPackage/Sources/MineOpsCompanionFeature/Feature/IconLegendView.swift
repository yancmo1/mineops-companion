import Observation
import SwiftUI

struct IconLegendView: View {
    @State private var library = IconLibrary.shared

    private let gridColumns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        @Bindable var iconLibrary = library

        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(iconLibrary.filteredIcons) { icon in
                        iconCard(for: icon, library: $iconLibrary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .background(Color.mineDark.ignoresSafeArea())
            .navigationTitle("Icon Legend")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Picker("Category", selection: $iconLibrary.selectedCategory) {
                            ForEach(iconLibrary.categories, id: \.self) { category in
                                Text(category)
                                    .tag(category)
                            }
                        }
                    } label: {
                        Label("Category", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .menuOrder(.fixed)
                }
            }
            .searchable(text: $iconLibrary.searchText, placement: .toolbar, prompt: "Search icons…")
            .overlay(alignment: .center) {
                if iconLibrary.icons.isEmpty {
                    ContentUnavailableView(
                        "No Icons",
                        systemImage: "square.stack.3d.up",
                        description: Text("Add PNGs to SMIcons folders or ensure icon_legend.json is available.")
                    )
                    .foregroundStyle(.white.opacity(0.7))
                } else if iconLibrary.filteredIcons.isEmpty {
                    ContentUnavailableView.search
                        .symbolVariant(.slash)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private func iconCard(for icon: IconInfo, library: Bindable<IconLibrary>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                iconPreview(for: icon, locked: false, library: library)
                iconPreview(for: icon, locked: true, library: library)
            }
            .frame(maxWidth: .infinity)

            Text(icon.displayName)
                .font(.headline)
                .foregroundStyle(.white)
                .accessibilityLabel(icon.displayName)

            Text(icon.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)

            Text(icon.boostCategory)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentCyan.opacity(0.15))
                .clipShape(Capsule())
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mineDarkLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.mineDarkLight.opacity(0.6), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(icon.displayName), \(icon.boostCategory) boost")
        .accessibilityHint(icon.description)
    }

    private func iconPreview(for icon: IconInfo, locked: Bool, library: Bindable<IconLibrary>) -> some View {
        Group {
            if let image = library.wrappedValue.image(for: icon, state: locked ? .locked : .unlocked) {
                image
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: locked ? "lock" : "questionmark")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    )
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 10))
                .padding(4)
                .background(Color.mineDarkLight.opacity(0.7))
                .clipShape(Circle())
                .foregroundStyle(.white)
                .offset(x: 6, y: 6)
        }
        .accessibilityLabel(locked ? "Locked icon" : "Unlocked icon")
    }
}

#Preview {
    IconLegendView()
        .preferredColorScheme(.dark)
}
