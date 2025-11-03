# PRD: AI Strategy Workflow System (Full Implementation)
**Module:** MineOps Companion → AI Strategy Assistant  
**Language:** Swift 6 / SwiftUI 3  
**Target:** iOS 18+, Xcode 16  
**Integration:** OpenAI Responses API (GPT-5 and GPT-5-Vision-Preview)  
**Owner:** Yancy Shepherd  

---

## 1️⃣  Overview
Automate detection and strategy generation for Idle Miner Tycoon Super Managers using GPT-5 Vision + text models with persistent Core Data caching.  
Users can upload screenshots → managers are auto-detected → GPT suggests optimal combos → results are cached and browsable in a history list.

---

## 2️⃣  File Structure
```
/App
 ├── Models/
 │   ├── ManagerRoster.swift
 │   ├── StrategyResponse.swift
 │   └── CoreDataManager.swift
 ├── Services/
 │   ├── AIStrategyEngine.swift
 │   └── AIStrategyPipeline.swift
 ├── Views/
 │   ├── StrategyPipelineView.swift
 │   ├── StrategyHistoryView.swift
 │   └── IconAlignmentView.swift   (existing)
 ├── Resources/
 │   ├── supermanagers.json
 │   └── AICacheModel.xcdatamodeld
```

---

## 3️⃣  Source Files

### 🟩 `ManagerRoster.swift`
```swift
import Foundation

struct SuperManager: Codable, Identifiable {
    let id: String
    let name: String
    let rarity: String
    let type: String
    let active: ActiveAbility?
    let passives: [PassiveAbility]?

    struct ActiveAbility: Codable {
        let description: String?
        let multiplier: Double?
        let duration: String?
        let cooldown: String?
    }

    struct PassiveAbility: Codable {
        let unlockLevel: Int
        let type: String
        let multiplier: Double?
        let description: String?
    }
}

final class ManagerRoster: ObservableObject {
    static let shared = ManagerRoster()
    @Published var managers: [SuperManager] = []

    private init() { load() }

    func load() {
        guard let url = Bundle.main.url(forResource: "supermanagers", withExtension: "json") else {
            print("⚠️ supermanagers.json not found"); return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: [SuperManager]].self, from: data)
            if let list = decoded["managers"] { managers = list.sorted { $0.name < $1.name } }
            print("✅ Loaded \(managers.count) managers")
        } catch { print("❌ Load failed:", error) }
    }

    var managerNames: [String] { managers.map { $0.name } }
}
```

---

### 🟩 `StrategyResponse.swift`
```swift
import Foundation

struct StrategyResponse: Codable, Identifiable {
    var id = UUID()
    let comboName: String
    let recommendedManagers: [String]
    let strategySummary: String
    let estimatedMultiplier: Double?
}
```

---

### 🟩 `CoreDataManager.swift`
```swift
import CoreData
import SwiftUI

final class CoreDataManager {
    static let shared = CoreDataManager()
    let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "AICacheModel")
        container.loadPersistentStores { desc, error in
            if let error = error { print("❌ CoreData load:", error) }
            else { print("✅ CoreData ready:", desc.url?.lastPathComponent ?? "") }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let ctx = container.viewContext
        if ctx.hasChanges { try? ctx.save() }
    }
}
```

---

### 🟩 `AIStrategyEngine.swift`
```swift
import Foundation
import UIKit

final class AIStrategyEngine: ObservableObject {
    static let shared = AIStrategyEngine()
    @Published var lastResult: StrategyResponse?
    @Published var isLoading = false

    func generateStrategy(
        mineName: String,
        mineLevel: Int,
        shaftLevel: Int,
        selectedManagers: [SuperManager],
        screenshots: [UIImage],
        notes: String?
    ) async {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else { return }
        isLoading = true; defer { isLoading = false }

        let managerList = selectedManagers.map { $0.name }.joined(separator: ", ")
        let prompt = """
        You are an Idle Miner Tycoon strategist.
        Mine: \(mineName) | Level: \(mineLevel) | Shaft: \(shaftLevel)
        Available Managers: \(managerList)
        Notes: \(notes ?? "None")
        Recommend the best combination and output JSON with:
        comboName, recommendedManagers, strategySummary, estimatedMultiplier
        """

        let url = URL(string: "https://api.openai.com/v1/responses")!
        let payload: [String: Any] = [
            "model": "gpt-5",
            "input": [["role": "user",
                       "content": [["type": "input_text", "text": prompt]]]],
            "response_format": "json"
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Raw: Codable { let output_text: String }
            let raw = try JSONDecoder().decode(Raw.self, from: data)
            let result = try JSONDecoder().decode(StrategyResponse.self, from: Data(raw.output_text.utf8))
            await MainActor.run { self.lastResult = result }
            print("✅ Strategy generated:", result.comboName)
        } catch { print("❌ Strategy error:", error) }
    }
}
```

---

### 🟩 `AIStrategyPipeline.swift`  (Core Data version with image hash cache)
```swift
import Foundation
import SwiftUI
import UIKit
import CryptoKit
import CoreData

@MainActor
final class AIStrategyPipeline: ObservableObject {
    static let shared = AIStrategyPipeline()
    @Published var isAnalyzing = false
    @Published var lastStrategy: StrategyResponse?
    @Published var detectedManagers: [String] = []

    private let ctx = CoreDataManager.shared.container.viewContext
    private let ocrModel = "gpt-5-vision-preview"

    // MARK: - Entry
    func runFullPipeline(
        mineName: String,
        mineLevel: Int,
        shaftLevel: Int,
        screenshots: [UIImage],
        notes: String?
    ) async {
        isAnalyzing = true; defer { isAnalyzing = false }

        if let cached = fetchCachedStrategy(mineName: mineName, mineLevel: mineLevel, shaftLevel: shaftLevel) {
            print("⚡️ Cached strategy used"); 
            detectedManagers = cached.detectedManagers ?? []
            lastStrategy = try? JSONDecoder().decode(StrategyResponse.self, from: Data((cached.strategyJSON ?? "").utf8))
            return
        }

        let managers = await detectManagers(from: screenshots)
        detectedManagers = managers

        await AIStrategyEngine.shared.generateStrategy(
            mineName: mineName, mineLevel: mineLevel, shaftLevel: shaftLevel,
            selectedManagers: managers.compactMap { name in
                ManagerRoster.shared.managers.first { $0.name == name }
            },
            screenshots: screenshots, notes: notes
        )

        guard let strategy = AIStrategyEngine.shared.lastResult else { return }
        storeStrategy(mineName: mineName, mineLevel: mineLevel, shaftLevel: shaftLevel,
                      managers: managers, strategy: strategy)
        lastStrategy = strategy
    }

    // MARK: - OCR w/ cache
    private func detectManagers(from screenshots: [UIImage]) async -> [String] {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else { return [] }
        var results: [String] = []

        for image in screenshots {
            guard let data = image.pngData() else { continue }
            let hash = Self.hashImage(data)
            if let cached = fetchDetection(hash: hash), let name = cached.managerName {
                results.append(name); continue
            }

            let base64 = data.base64EncodedString()
            let url = URL(string: "https://api.openai.com/v1/responses")!
            let payload: [String: Any] = [
                "model": ocrModel,
                "input": [[
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": "Identify Idle Miner Tycoon manager icon → JSON {\"manager\":\"<name>\"}"],
                        ["type": "input_image", "image_data": base64]
                    ]
                ]],
                "response_format": "json"
            ]

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                struct Raw: Codable { let output_text: String }
                let raw = try JSONDecoder().decode(Raw.self, from: data)
                struct Simple: Codable { let manager: String }
                if let mgr = try? JSONDecoder().decode(Simple.self, from: Data(raw.output_text.utf8)) {
                    results.append(mgr.manager)
                    storeDetection(hash: hash, name: mgr.manager)
                    print("🧠 Detected:", mgr.manager)
                }
            } catch { print("❌ OCR failed:", error) }
        }
        return Array(Set(results))
    }

    // MARK: - CoreData helpers
    private func fetchCachedStrategy(mineName: String, mineLevel: Int, shaftLevel: Int)
        -> CachedStrategyEntity? {
        let r = NSFetchRequest<CachedStrategyEntity>(entityName: "CachedStrategy")
        r.predicate = NSPredicate(format: "mineName == %@ AND mineLevel == %d AND shaftLevel == %d",
                                  mineName, mineLevel, shaftLevel)
        r.fetchLimit = 1
        return try? ctx.fetch(r).first
    }

    private func storeStrategy(mineName: String, mineLevel: Int, shaftLevel: Int,
                               managers: [String], strategy: StrategyResponse) {
        let e = CachedStrategyEntity(context: ctx)
        e.mineName = mineName
        e.mineLevel = Int64(mineLevel)
        e.shaftLevel = Int64(shaftLevel)
        e.detectedManagers = managers
        e.strategyJSON = String(data: try! JSONEncoder().encode(strategy), encoding: .utf8)
        e.timestamp = Date()
        CoreDataManager.shared.save()
    }

    private func fetchDetection(hash: String) -> CachedDetectionEntity? {
        let r = NSFetchRequest<CachedDetectionEntity>(entityName: "CachedDetection")
        r.predicate = NSPredicate(format: "hash == %@", hash)
        r.fetchLimit = 1
        return try? ctx.fetch(r).first
    }

    private func storeDetection(hash: String, name: String) {
        let e = CachedDetectionEntity(context: ctx)
        e.hash = hash; e.managerName = name; e.timestamp = Date()
        CoreDataManager.shared.save()
    }

    func clearAllCaches() {
        ["CachedStrategy","CachedDetection"].forEach {
            let f = NSFetchRequest<NSFetchRequestResult>(entityName: $0)
            let del = NSBatchDeleteRequest(fetchRequest: f)
            _ = try? ctx.execute(del)
        }
        CoreDataManager.shared.save()
    }

    private static func hashImage(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
```

---

### 🟩 `StrategyPipelineView.swift`
```swift
import SwiftUI
import PhotosUI

struct StrategyPipelineView: View {
    @ObservedObject private var pipeline = AIStrategyPipeline.shared
    @State private var mineName = "Frontier Mine"
    @State private var mineLevel = 120
    @State private var shaftLevel = 25
    @State private var notes = "POC run"
    @State private var screenshots: [UIImage] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextField("Mine", text: $mineName).textFieldStyle(.roundedBorder)
                Stepper("Mine Level \(mineLevel)", value: $mineLevel, in: 1...999)
                Stepper("Shaft Level \(shaftLevel)", value: $shaftLevel, in: 1...999)
                TextField("Notes", text: $notes).textFieldStyle(.roundedBorder)

                PhotosPicker(selection: Binding(get: { nil }, set: { item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) { screenshots.append(img) }
                    }
                }), matching: .images) { Label("Add Screenshot", systemImage: "photo.on.rectangle") }

                Button {
                    Task {
                        await pipeline.runFullPipeline(
                            mineName: mineName, mineLevel: mineLevel,
                            shaftLevel: shaftLevel, screenshots: screenshots, notes: notes)
                    }
                } label: {
                    Text(pipeline.isAnalyzing ? "Analyzing…" : "Run AI Strategy")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pipeline.isAnalyzing)

                if let result = pipeline.lastStrategy {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.comboName).font(.headline)
                        Text("Managers: " + result.recommendedManagers.joined(separator: ", "))
                        Text(result.strategySummary)
                        if let m = result.estimatedMultiplier {
                            Text("≈ \(m, specifier: "%.2f")× Boost").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.mineDarkLight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !pipeline.detectedManagers.isEmpty {
                    Text("Detected: " + pipeline.detectedManagers.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                }

                NavigationLink("View History") { StrategyHistoryView() }
                    .buttonStyle(.bordered)
                Spacer()
            }
            .padding()
            .navigationTitle("AI Strategy Pipeline")
            .toolbar { Button("Clear Cache") { pipeline.clearAllCaches() } }
        }
    }
}
```

---

### 🟩 `StrategyHistoryView.swift`
```swift
import SwiftUI
import CoreData

struct StrategyHistoryView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\.timestamp, order: .reverse)])
    private var entries: FetchedResults<CachedStrategyEntity>

    var body: some View {
        List {
            ForEach(entries) { e in
                VStack(alignment: .leading, spacing: 4) {
                    Text(e.mineName ?? "Unknown Mine")
                        .font(.headline)
                    Text("L\(e.mineLevel) / S\(e.shaftLevel)")
                        .font(.caption)
                    if let m = e.detectedManagers {
                        Text(m.joined(separator: ", ")).font(.caption2)
                    }
                    Text(e.timestamp ?? Date(), style: .date)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Strategy History")
        .toolbar { EditButton() }
    }

    private func delete(offsets: IndexSet) {
        let ctx = CoreDataManager.shared.container.viewContext
        offsets.map { entries[$0] }.forEach(ctx.delete)
        CoreDataManager.shared.save()
    }
}
```

---

## 4️⃣ Core Data Model (`AICacheModel.xcdatamodeld`)
**Entities**

### CachedDetection
| Attribute | Type |
|------------|------|
| hash | String |
| managerName | String |
| timestamp | Date |

### CachedStrategy
| Attribute | Type |
|------------|------|
| mineName | String |
| mineLevel | Integer 64 |
| shaftLevel | Integer 64 |
| detectedManagers | Transformable ([String]) |
| strategyJSON | String |
| timestamp | Date |

---

## 5️⃣ OpenAI Configuration
- `OPENAI_API_KEY` must be available in environment variables or `Info.plist` (`App > Scheme > Environment Variables`).  
- Endpoints used:  
  - `https://api.openai.com/v1/responses`  
- Models:  
  - OCR → `gpt-5-vision-preview`  
  - Strategy → `gpt-5`

---

## ✅ Acceptance Criteria
- Runs full OCR → Strategy chain successfully with valid key.  
- Re-uploading identical screenshots triggers zero new OCR calls.  
- Cached strategies persist after relaunch.  
- “Strategy History” lists and deletes stored entries cleanly.  
- Builds & runs on iOS 18 simulator without runtime errors.

---

**End of PRD / Implementation**
