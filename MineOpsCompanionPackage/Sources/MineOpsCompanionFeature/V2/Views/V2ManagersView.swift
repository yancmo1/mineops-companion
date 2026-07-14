import SwiftUI

// MARK: - FlowLayout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowLayoutResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayoutResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowLayoutResult {
        var size: CGSize
        var positions: [CGPoint]
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)
                
                if currentX + subviewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += subviewSize.width + spacing
                lineHeight = max(lineHeight, subviewSize.height)
                size.width = max(size.width, currentX - spacing)
                size.height = currentY + lineHeight
            }
            
            self.size = size
            self.positions = positions
        }
    }
}

struct V2ManagersView: View {
    @Environment(SMProgressService.self) private var progressService

    @State private var searchText = ""
    @State private var selectedDepartment: SMDepartment?
    @State private var ownershipFilter: ManagerOwnershipFilter = .unlocked
    @State private var sortOption: ManagerSortOption = .recommended
    @State private var showAdvancedFilters = false
    @State private var selectedRarities: Set<String> = []
    @State private var upgradeReadyOnly = false

    private let rarityOptions = ["legendary", "epic", "rare", "common"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // Grid
                ScrollView {
                    if filteredSMs.isEmpty {
                        emptyState
                            .padding(.horizontal)
                            .padding(.top, 24)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(filteredSMs) { sm in
                                NavigationLink(destination: V2ManagerDetailView(sm: sm)) {
                                    V2SMCardView(sm: sm)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .background(Color.mineDark.ignoresSafeArea())
            .navigationTitle("Super Managers")
            .searchable(text: $searchText, prompt: "Search managers…")
            .sheet(isPresented: $showAdvancedFilters) {
                advancedFiltersSheet
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                filterChip("All", department: nil)
                ForEach(SMDepartment.allCases, id: \.self) { dept in
                    filterChip(dept.displayName, department: dept)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Picker("Ownership", selection: $ownershipFilter) {
                    ForEach(ManagerOwnershipFilter.allCases) { ownership in
                        Text(ownership.displayName).tag(ownership)
                    }
                }
                .pickerStyle(.segmented)

                Menu {
                    Section("Sort") {
                        ForEach(ManagerSortOption.allCases) { option in
                            Button {
                                sortOption = option
                            } label: {
                                Label(option.displayName, systemImage: sortOption == option ? "checkmark" : "")
                            }
                        }
                    }

                    Section("Filters") {
                        Button {
                            showAdvancedFilters = true
                        } label: {
                            Label("Advanced Filters", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.headline)
                        .foregroundStyle(Color.accentCyan)
                        .padding(8)
                        .background(Color.mineDarkLight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text("\(filteredSMs.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.mineDarkLight)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("managersResultCount")
            }
        }
    }

    private func filterChip(_ label: String, department: SMDepartment?) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDepartment = department
            }
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedDepartment == department ? Color.accentCyan : Color.mineDarkLight)
                .foregroundStyle(selectedDepartment == department ? Color.mineDark : .white)
                .clipShape(Capsule())
        }
    }

    private var filteredSMs: [SMProgress] {
        let query = ManagerListQuery(
            searchText: searchText,
            department: selectedDepartment,
            ownership: ownershipFilter,
            selectedRarities: selectedRarities,
            upgradeReadyOnly: upgradeReadyOnly,
            sort: sortOption
        )

        return query.apply(to: progressService.progress, progressService: progressService)
    }

    private var advancedFiltersSheet: some View {
        NavigationStack {
            Form {
                Section("Rarity") {
                    ForEach(rarityOptions, id: \.self) { rarity in
                        Toggle(isOn: Binding(
                            get: { selectedRarities.contains(rarity) },
                            set: { enabled in
                                if enabled {
                                    selectedRarities.insert(rarity)
                                } else {
                                    selectedRarities.remove(rarity)
                                }
                            }
                        )) {
                            Text(rarity.capitalized)
                        }
                    }
                }

                Section("Readiness") {
                    Toggle("Rank-up Ready Only", isOn: $upgradeReadyOnly)
                }

                Section {
                    Button("Clear Filters") {
                        selectedRarities = []
                        upgradeReadyOnly = false
                    }
                    .accessibilityIdentifier("managersClearFiltersButton")
                }
            }
            .navigationTitle("Advanced Filters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showAdvancedFilters = false }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            if ownershipFilter == .unlocked && progressService.unlockedCount == 0 {
                Text("No unlocked managers are available yet.")
                    .font(.headline)
                Text("Sync your game data to refresh MineOps.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No managers match \"\(searchText)\".")
                    .font(.headline)
            } else {
                Text("No managers match the selected filters.")
                    .font(.headline)
                Button("Clear Filters") {
                    selectedDepartment = nil
                    selectedRarities = []
                    upgradeReadyOnly = false
                    ownershipFilter = .unlocked
                    sortOption = .recommended
                }
                .buttonStyle(.bordered)
            }
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - SM Card

struct V2SMCardView: View {
    let sm: SMProgress

    var body: some View {
        VStack(spacing: 0) {
            // Sprite area
            spriteView
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(sm.unlocked ? rarityColor(sm.master.rarity).opacity(0.15) : Color.mineDarkLight)
                .overlay(alignment: .topTrailing) {
                    if !sm.unlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                }

            // Info area
            VStack(alignment: .leading, spacing: 2) {
                Text(sm.master.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .foregroundStyle(Color.primary)

                HStack(spacing: 4) {
                    Text(sm.master.rarity.capitalized)
                        .font(.system(size: 9))
                        .foregroundStyle(rarityColor(sm.master.rarity))
                    Spacer()
                    Text(sm.areaEnum.displayName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(areaColor(sm.areaEnum))
                }

                if sm.unlocked {
                    HStack(spacing: 6) {
                        Label("Lv\(sm.level)", systemImage: "arrow.up")
                            .font(.system(size: 9))
                        Label("P\(sm.promoted)", systemImage: "star.fill")
                            .font(.system(size: 9))
                        Label("R\(sm.rank)", systemImage: "bolt.fill")
                            .font(.system(size: 9))
                        if sm.fragments > 0 {
                            Label("⬥\(sm.fragments)", systemImage: "")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("managerCardUnlockedStats_\(sm.id)")

                    if SMProgressService.shared.isRankUpReady(sm) {
                        Text("Ready to Rank Up")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(Color.green)
                            .clipShape(Capsule())
                            .accessibilityIdentifier("managerCardRankReady_\(sm.id)")
                    }
                } else if sm.fragments > 0 {
                    Text("\(sm.fragments) fragments")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mineDarkLight.opacity(0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(sm.unlocked ? rarityColor(sm.master.rarity).opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var spriteView: some View {
        if sm.unlocked, let url = SMMasterDataService.shared.spriteURL(for: sm.master) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                case .failure:
                    spritePlaceholder
                case .empty:
                    ProgressView()
                        .tint(.secondary)
                @unknown default:
                    spritePlaceholder
                }
            }
        } else {
            spritePlaceholder
        }
    }

    private var spritePlaceholder: some View {
        Image(systemName: "person.fill.questionmark")
            .font(.title2)
            .foregroundStyle(.secondary)
    }

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "common": return .gray
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .secondary
        }
    }

    private func areaColor(_ dept: SMDepartment) -> Color {
        switch dept {
        case .mineshaft: return .accentOrange
        case .elevator: return .accentCyan
        case .warehouse: return .purple
        }
    }
}

// MARK: - Manager Detail

struct V2ManagerDetailView: View {
    let sm: SMProgress
    
    private var activeValue: Double {
        sm.effectiveActiveValue(using: SMMasterDataService.shared.activeScaling)
    }
    
    private var computedPassives: [ComputedPassive] {
        sm.computedPassives(using: SMMasterDataService.shared.passiveTables)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                VStack(spacing: 12) {
                    spriteView
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .background(rarityColor(sm.master.rarity).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Text(sm.master.name)
                        .font(.title.bold())

                    HStack(spacing: 12) {
                        badge(sm.master.rarity.capitalized, color: rarityColor(sm.master.rarity))
                        badge(sm.areaEnum.displayName, color: areaColor(sm.areaEnum))
                    }

                    if sm.unlocked {
                        HStack(spacing: 16) {
                            statBlock("Level", "\(sm.level)")
                            statBlock("Promotion", "\(sm.promoted)")
                            statBlock("Rank", "\(sm.rank)")
                            if sm.fragments > 0 {
                                statBlock("Fragments", "\(sm.fragments)")
                            }
                        }
                    }
                }
                .padding()
                .background(Color.mineDarkLight.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Active ability
                if sm.unlocked {
                    abilitySection
                }

                // Passives
                if !computedPassives.isEmpty {
                    passivesSection
                }

                // Elements
                if !sm.sortedElements.isEmpty {
                    elementsSection
                }
            }
            .padding(.vertical)
        }
        .background(Color.mineDark.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var abilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Ability")
                .font(.title3.bold())
                .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 0.8))
            
            VStack(alignment: .leading, spacing: 16) {
                Text(interpolatedDescription)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.2fx", activeValue))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("Value")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatTime(sm.master.cooldown))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("Cooldown")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatTime(sm.master.duration))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("Duration")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var interpolatedDescription: String {
        var description = sm.master.descriptionShort ?? sm.master.descriptionLong ?? ""
        
        let effectType = SMMasterDataService.shared.activeScaling[sm.master.id]?.type
        
        // Format the value based on effect type
        let valueStr: String
        if effectType == 3 {
            // Type 3 = cost reduction percentage
            valueStr = String(format: "-%.2f%%", activeValue * 100)
        } else {
            // Default = multiplier
            valueStr = String(format: "%.2fx", activeValue)
        }
        
        let cooldownStr = formatTime(sm.master.cooldown)
        let durationStr = formatTime(sm.master.duration)
        
        description = description.replacingOccurrences(of: "{0}", with: valueStr)
        description = description.replacingOccurrences(of: "{1}", with: cooldownStr)
        description = description.replacingOccurrences(of: "{2}", with: durationStr)
        description = description.replacingOccurrences(of: "{3}", with: "(bonus)")
        
        return description
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes > 0 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }

    private var passivesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Passive Abilities")
                .font(.title3.bold())
                .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 0.8))
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(computedPassives) { passive in
                    HStack {
                        Text(passive.typeDisplayName)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        if let value = passive.value {
                            Text(String(format: "%.2fx", value))
                                .font(.body.bold())
                                .foregroundStyle(.blue)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                        Text("P\(passive.entry.promoReq * 10)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.bottom, passive.id != computedPassives.last?.id ? 8 : 0)
                }
            }
        }
        .padding(.horizontal)
    }

    private var elementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Element Affinities")
                .font(.title3.bold())
                .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 0.8))
            
            VStack(alignment: .leading, spacing: 12) {
                // Group by effectiveness
                let seElements = sm.sortedElements.filter { $0.effectiveness == "SE" }
                let peElements = sm.sortedElements.filter { $0.effectiveness == "PE" }
                let nveElements = sm.sortedElements.filter { $0.effectiveness == "NVE" }
                
                if !seElements.isEmpty {
                    elementRow(label: "SE unlocks:", elements: seElements, color: .green)
                }
                if !peElements.isEmpty {
                    elementRow(label: "PE:", elements: peElements, color: .blue)
                }
                if !nveElements.isEmpty {
                    elementRow(label: "NVE:", elements: nveElements, color: .orange)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private func elementRow(label: String, elements: [SMMasterEntry.SMElementEntry], color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
            
            FlowLayout(spacing: 6) {
                ForEach(elements, id: \.element) { element in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(elementColor(element.element))
                            .frame(width: 12, height: 12)
                        Text(element.element.capitalized)
                            .font(.caption)
                        if element.rankReq > 0 {
                            Text("at rank \(element.rankReq)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.15))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color, lineWidth: 1)
                    )
                }
            }
        }
    }
    
    private func elementColor(_ element: String) -> Color {
        switch element.lowercased() {
        case "fire": return .red
        case "water": return .blue
        case "wind": return .cyan
        case "earth": return .brown
        case "lightning": return .yellow
        case "dark": return .purple
        case "light": return .orange
        case "nature": return .green
        case "sand": return Color(red: 0.8, green: 0.7, blue: 0.4)
        case "chrome": return .gray
        case "orb": return Color(red: 0.6, green: 0.4, blue: 0.8)
        default: return .gray
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func statBlock(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var spriteView: some View {
        if let url = SMMasterDataService.shared.spriteURL(for: sm.master) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                default:
                    Image(systemName: "person.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
        }
    }

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "common": return .gray
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .secondary
        }
    }

    private func areaColor(_ dept: SMDepartment) -> Color {
        switch dept {
        case .mineshaft: return .accentOrange
        case .elevator: return .accentCyan
        case .warehouse: return .purple
        }
    }

    private func effectivenessLabel(_ eff: String) -> String {
        switch eff {
        case "SE": return "Strong"
        case "PE": return "Standard"
        case "NVE": return "Weak"
        default: return eff
        }
    }

    private func effectivenessColor(_ eff: String) -> Color {
        switch eff {
        case "SE": return .green
        case "PE": return .primary
        case "NVE": return .red
        default: return .secondary
        }
    }
}
