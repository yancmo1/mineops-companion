# MineOps Companion – iOS SwiftUI Skeleton

## 1. Project Summary
Private iOS-only companion app for *Idle Miner Tycoon* that:
- Imports multiple screenshots of your Super Managers.  
- Runs on-device OCR to extract names, levels, and boosts.  
- Matches those entries to a local static SM Directory JSON.  
- Generates a strategy summary (best active team, upgrade priorities).  
- Exports results as Markdown or text via iOS Share Sheet.

---

## 2. Environment Setup
### Required
- **Xcode 15 or newer**
- **iOS 16 SDK + Swift 5.9**
- macOS Ventura or later

### Optional (advanced)
- Homebrew (`brew install swiftlint`)
- Vision Framework reference docs (for OCR)

---

## 3. Create the App Scaffold
In Xcode:

1. **New Project → iOS App**
2. Product Name: `MineOpsCompanion`
3. Interface: `SwiftUI`
4. Language: `Swift`
5. Save to your local development folder.

---

## 4. Directory Structure
```
MineOpsCompanion/
 ├─ App/
 │   ├─ MineOpsCompanionApp.swift
 │   ├─ ContentView.swift
 ├─ Models/
 │   ├─ SuperManager.swift
 │   ├─ OCRResult.swift
 ├─ OCR/
 │   ├─ OCRProcessor.swift
 │   ├─ OCRReviewView.swift
 ├─ Strategy/
 │   ├─ StrategyEngine.swift
 │   ├─ StrategySummaryView.swift
 ├─ Data/
 │   ├─ sm_directory.json
 │   ├─ Persistence.swift
 ├─ Export/
 │   ├─ ExportManager.swift
 ├─ Resources/
 │   ├─ Assets.xcassets
 │   ├─ LaunchScreen.storyboard
 └─ Tests/
     ├─ OCRTests.swift
     ├─ StrategyEngineTests.swift
```

---

## 5. Core Files – Starter Code

### **MineOpsCompanionApp.swift**
```swift
import SwiftUI

@main
struct MineOpsCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### **ContentView.swift**
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "gearshape.2.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .foregroundStyle(.blue)
                    .padding(.top, 60)

                Text("MineOps Companion")
                    .font(.title)
                    .bold()

                NavigationLink("Import Screenshots") {
                    OCRReviewView()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Strategy Summary") {
                    StrategySummaryView()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}
```

### **SuperManager.swift**
```swift
import Foundation

struct SuperManager: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var role: String
    var baseBoost: Double
    var maxBoost: Double
    var boostType: String
    var cost: Int?
    var imageName: String?
}
```

### **OCRResult.swift**
```swift
import Foundation
import SwiftUI

struct OCRResult: Identifiable, Hashable {
    let id = UUID()
    var image: UIImage
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
import Foundation

final class StrategyEngine {
    func generateSummary(for managers: [OCRResult]) -> String {
        let top = managers.sorted { $0.parsedBoost > $1.parsedBoost }.prefix(5)
        var summary = "Top Super Managers by Boost:\n"
        for sm in top {
            summary += "- \(sm.parsedName): +\(Int(sm.parsedBoost))% \(sm.parsedBoostType)\n"
        }
        return summary
    }
}
```

### **StrategySummaryView.swift**
```swift
import SwiftUI

struct StrategySummaryView: View {
    @State private var summary: String = "No data yet."
    private let engine = StrategyEngine()

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
4. Integrate export logic (`ExportManager.swift`) to share Markdown.  
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