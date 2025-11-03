# MineOps Companion – Development Setup

## 1. Project Summary
Production iOS companion app for *Idle Miner Tycoon* that:
- Imports multiple screenshots of your Super Managers
- Runs on-device OCR to extract 13+ data points (name, department, rarity, stars, abilities, action buttons)
- Matches entries to a local static SM Directory JSON
- Provides full CRUD operations for your manager database
- Generates strategy summaries with department coverage analysis

---
## 2. Environment Setup
### Required
- **Xcode 16 or newer**
- **iOS 17 SDK + Swift 6.1**
- macOS Sonoma or later

### Optional
- Homebrew (`brew install swift-format`)
- Bundler for Fastlane (`gem install bundler`)
- Vision Framework reference docs (for OCR)

### Initial Setup
```bash
## 3. Project Structure

This project uses a **workspace + Swift Package** architecture:

```
MineOpsCompanion/
├── MineOpsCompanion.xcworkspace/              # Open this in Xcode
├── MineOpsCompanion.xcodeproj/                # App shell
├── MineOpsCompanion/                          # App target (minimal)
│   ├── MineOpsCompanionApp.swift              # App entry point
│   └── Assets.xcassets/                       # App icons/colors
├── MineOpsCompanionPackage/                   # Primary development area
│   ├── Package.swift                          # Package manifest
│   ├── Sources/MineOpsCompanionFeature/       # All feature code
│   │   ├── ContentView.swift                  # Root TabView
│   │   ├── Models/                            # Domain models
│   │   │   ├── RecognizedSM.swift             # Recognized manager
│   │   │   ├── SMDirectoryEntry.swift         # Directory entry
│   │   │   └── SMStats.swift                  # Manager stats
│   │   ├── OCR/                               # OCR processing
│   │   │   ├── OCRProcessor.swift             # Vision integration
│   │   │   ├─ OCRReviewView.swift            # Manager list + CRUD
│   │   │   ├── OCRLevelParser.swift           # Level/promo parsing
│   │   │   ├── OCRParsing.swift               # Directory matching
│   │   │   └── OCRFieldExtraction.swift       # Field extraction
│   │   ├── Data/                              # Persistence
│   │   │   └── Persistence.swift              # JSON save/load
│   │   ├── Strategy/                          # Strategy engine
│   │   │   ├── StrategyEngine.swift           # Optimization logic
│   │   │   ├── StrategySummaryView.swift      # Strategy UI
│   │   │   └── CommandCenterViewV2.swift      # Dashboard
│   │   ├── Resources/                         # Static data
│   │   │   └── sm_directory.json              # Manager database
│   │   └── Support/
│   │       └── ResourceLoader.swift           # JSON loading
│   └── Tests/MineOpsCompanionFeatureTests/    # Unit tests
│       ├── DirectoryMatcherTests.swift
## 4. Architecture Details

### OCR Pipeline

The OCR processing uses VisionKit with comprehensive field extraction:

```swift
// OCR flow
let processor = OCRProcessor()
let results = await processor.processImages([uiImage])
// Results contain RecognizedSM with 13+ extracted fields
```

**Pipeline stages:**
1. **Vision Recognition**: `VNRecognizeTextRequest` with accurate level
2. **Directory Matching**: Token Jaccard + substring scoring (0.30 threshold)
3. **Field Extraction**: Regex-based parsing of:
   - Rarity (Common/Rare/Epic/Legendary)
   - Role/Department (Mineshaft/Elevator/Warehouse)
   - Stars (1-5)
   - Active ability (effect, multiplier, duration, cooldown)
   - Passive ability (effect, multiplier, duration)
   - Action buttons (Level Up, Promote, Rank Up)

### Persistence

JSON serialization to ApplicationSupport with image storage:

```swift
// Save/load flow
Persistence.saveRecognized(managers)
let loaded = Persistence.loadRecognized()
```
```swift
struct RecognizedSM: Identifiable, Hashable {
  let id: UUID
  let image: UIImage
  let recognizedText: String
  let stats: SMStats
  let directory: SMDirectoryEntry?
  
  // Extended OCR fields
  let rarity: String?
  let role: String?
  let stars: Int?
  let active: ActiveInfo?
  let passive: PassiveInfo?
  let actions: ActionFlags?
  
  struct ActiveInfo: Hashable, Codable {
    let effect: String
    let multiplier: Double?
    let durationSeconds: Int?
    let cooldownSeconds: Int?
  }
  
  struct PassiveInfo: Hashable, Codable {
    let effect: String
    let multiplier: Double?
    let durationSeconds: Int?
  }
  
  struct ActionFlags: Hashable, Codable {
    let hasLevelUp: Bool
    let hasPromote: Bool
    let hasRankUp: Bool
  }
}
```

### **OCRProcessor Integration**
```swift
import Vision
import VisionKit

final class OCRProcessor {
  func processImages(_ images: [UIImage]) async -> [RecognizedSM] {
    var results: [RecognizedSM] = []
    for image in images {
      guard let cgImage = image.cgImage else { continue }
      let text = await recognizeText(from: cgImage)
      
      // Match to directory
      let match = DirectoryMatcher.bestMatch(in: text, directory: SMDirectory.shared.entries)
      
      // Extract all fields
      let fields = OCRFieldExtraction.extract(from: text)
      
      // Parse stats
      let stats = SMStatsParser.parse(from: text)
      
      let recognized = RecognizedSM(
        id: UUID(),
        image: image,
        recognizedText: text,
        stats: stats,
        directory: match,
        rarity: fields.rarity,
        role: fields.role,
        stars: fields.stars,
        active: fields.hasActive ? RecognizedSM.ActiveInfo(
          effect: fields.activeEffect ?? "",
          multiplier: fields.activeMultiplier,
          durationSeconds: fields.activeDuration,
          cooldownSeconds: fields.cooldownSeconds
        ) : nil,
        passive: fields.hasPassive ? RecognizedSM.PassiveInfo(
          effect: fields.passiveEffect ?? "",
          multiplier: fields.passiveMultiplier,
          durationSeconds: fields.passiveDuration
        ) : nil,
        actions: RecognizedSM.ActionFlags(
          hasLevelUp: fields.hasLevelUp,
          hasPromote: fields.hasPromote,
          hasRankUp: fields.hasRankUp
        )
      )
      results.append(recognized)
    }
    return results
  }
}
```

---

## 9. Next Steps

### Immediate
- [x] OCR field extraction (13+ data points)
- [x] Directory matching with scoring
- [x] Manager CRUD operations
- [x] Debug field display
- [x] Persistence with image storage
- [x] CI workflow setup
- [x] Code formatting configuration
- [x] Fastlane automation

### Short-term
- [ ] CSV/JSON export functionality
- [ ] Strategy engine optimization
- [ ] Department readiness calculations
- [ ] Dark mode polish
- [ ] Icon set completion

### Long-term
- [ ] iCloud sync
- [ ] Widget support
- [ ] Watch app
- [ ] Advanced combo analysis
    var parsedName: String
    var parsedLevel: Int
    var parsedBoost: Double
    var parsedBoostType: String
}
```

### **OCRProcessor.swift**
```swift
import Vision
import VisionKit
import SwiftUI

final class OCRProcessor: ObservableObject {
    @Published var results: [OCRResult] = []

    func processImages(_ images: [UIImage]) async {
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let request = VNRecognizeTextRequest { [weak self] req, _ in
                guard let obs = req.results as? [VNRecognizedTextObservation] else { return }
                let allText = obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                let parsed = self?.parseText(allText) ?? OCRResult(image: image, parsedName: "Unknown", parsedLevel: 0, parsedBoost: 0, parsedBoostType: "")
                DispatchQueue.main.async { self?.results.append(parsed) }
            }
            request.recognitionLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func parseText(_ text: String) -> OCRResult {
        let name = text.components(separatedBy: "Level").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        let level = Int(text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) ?? 0
        let boostMatch = text.range(of: #"\+\d+%"#, options: .regularExpression)
        let boostString = boostMatch.map { String(text[$0]) } ?? "+0%"
        let boostValue = Double(boostString.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "%", with: "")) ?? 0
        return OCRResult(image: UIImage(), parsedName: name, parsedLevel: level, parsedBoost: boostValue, parsedBoostType: "")
    }
}
```

### **OCRReviewView.swift**
```swift
import SwiftUI
import PhotosUI

struct OCRReviewView: View {
    @StateObject private var ocr = OCRProcessor()
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        VStack {
            PhotosPicker("Select Screenshots", selection: $selectedPhotos, matching: .images, photoLibrary: .shared())
                .onChange(of: selectedPhotos) { _ in Task { await importSelected() } }

            List(ocr.results) { result in
                VStack(alignment: .leading) {
                    Text(result.parsedName).font(.headline)
                    Text("Level \(result.parsedLevel)   +\(Int(result.parsedBoost))% \(result.parsedBoostType)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .navigationTitle("Import & Review")
    }

    private func importSelected() async {
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await ocr.processImages([img])
            }
        }
    }
}
```

### **StrategyEngine.swift**
```swift
---

## 10. Contributing

### Code Style
- Follow `.swift-format` configuration
- Use Swift 6.1+ concurrency (async/await)
- Prefer Model-View over MVVM
- Write tests with Swift Testing framework

### Pull Request Process
1. Create feature branch from `main`
2. Make changes, write tests
3. Format code: `./scripts/format.sh`
4. Push and open PR (CI will validate)
5. Request review

---

*Author: Yancy Shepherd · Internal Project: MineOps Companion · 2025*
    var body: some View {
        ScrollView {
            Text(summary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Strategy Summary")
        .toolbar {
            Button("Generate") { generateMockSummary() }
        }
    }

    private func generateMockSummary() {
        let mock = [
            OCRResult(image: UIImage(), parsedName: "Mr. Edmund", parsedLevel: 10, parsedBoost: 650, parsedBoostType: "Warehouse"),
            OCRResult(image: UIImage(), parsedName: "Freesia", parsedLevel: 9, parsedBoost: 480, parsedBoostType: "Transport"),
            OCRResult(image: UIImage(), parsedName: "H4V0C", parsedLevel: 7, parsedBoost: 400, parsedBoostType: "Mine")
        ]
        summary = engine.generateSummary(for: mock)
    }
}
```

---

## 6. Next Steps for GitHub Agent
1. Implement OCR error-handling and batch progress UI.  
2. Load real SM Directory (`sm_directory.json`) and match parsed names.  
3. Build editable Review UI (tap to correct parsed fields).  
5. Add CoreData for persistent storage.  
6. Polish interface (icons, dark mode).  
7. Prepare README + MIT License.

---

## 7. Version Control Setup
```bash
git init
echo ".DS_Store" >> .gitignore
echo "DerivedData/" >> .gitignore
git add .
git commit -m "Initial SwiftUI skeleton for MineOps Companion"
```

---

## 8. Optional Enhancements
- Auto-filter screenshots by image hash or filename pattern.  
- Snapshot History (store OCR results + timestamp).  
- Dynamic heatmap of boosts by role.  
- Local AI (GPT-5 API hook) for advanced combo analysis.

---

*Author: Yancy Shepherd  · Internal Project: MineOps Companion · 2025-10-27*
