# MineOps Companion – iOS SwiftUI Skeleton

## 1. Project Summary
Production-ready iOS companion app for *Idle Miner Tycoon* that:
- **Batch Image Import**: PhotosPicker integration for multiple Super Manager screenshots
- **Advanced OCR**: VisionKit text recognition with 13+ field extraction (rarity, role, stars, active/passive abilities, cooldowns, action flags)
- **Smart Matching**: Directory matching with token-based Jaccard similarity (0.30 threshold) and substring containment
- **Manager Database**: Full CRUD operations (create via import, edit in sheets, swipe-to-delete)
- **Strategic Analysis**: Department coverage summaries, readiness gauges, optimal manager recommendations
- **Persistence**: JSON + PNG storage in ApplicationSupport with automatic orphan cleanup
- **Export**: CSV export for external analysis (ShareSheet integration)

## 2. Environment Setup
### Required
- **Xcode 16 or newer**
- **Swift 6.1** (strict concurrency enabled)
- **iOS 17 SDK** (deployment target iOS 17.0)
- macOS Ventura or later

### Optional (for CI/Formatting)
- **Homebrew**: `brew install swift-format` for code formatting
- **Bundler**: `gem install bundler` for Fastlane dependency management
- **Vision Framework**: Reference docs for OCR customization
- **XcodeBuildMCP**: AI-assisted iOS development tools

## 3. Getting Started

### Clone and Open
```bash
git clone https://github.com/yancmo1/mineops-companion.git
cd mineops-companion
open MineOpsCompanion.xcworkspace  # Always open .xcworkspace, not .xcodeproj
```

### Install Fastlane (Optional)
### Install Fastlane (Optional)
```bash
bundle install
```

This installs Fastlane and xcpretty from the `Gemfile`.

## 4. Directory Structure (Current Implementation)
MineOpsCompanion/
├── MineOpsCompanion.xcworkspace/              # Open this in Xcode
├── MineOpsCompanion.xcodeproj/                # App shell project
├── MineOpsCompanion/
│   ├── MineOpsCompanionApp.swift              # App entry point
│   ├── Assets.xcassets/                # App icon, accent color
│   └── MineOpsCompanion.xctestplan            # Test plan configuration
├── MineOpsCompanionPackage/                   # 🚀 Primary development area
│   ├── Package.swift                   # SPM package configuration
│   ├── Sources/MineOpsCompanionFeature/
│   │   ├── ContentView.swift           # Root TabView coordinator
│   │   ├── Data/
│   │   │   └── Persistence.swift       # JSON + PNG storage
│   │   ├── Export/
│   │   │   └── ExportManager.swift     # CSV export utilities
│   │   ├── Models/
│   │   │   ├── OCRResult.swift         # RecognizedSM, OCRFieldExtraction
│   │   │   └── SuperManager.swift      # SMDirectoryEntry, SMStats
│   │   ├── OCR/
│   │   ├── Strategy/
│   │   │   ├── StrategyEngine.swift    # Boost calculations
## 5. Key Implementation Detailswift    # Bundle resource utilities
│   └── Tests/MineOpsCompanionFeatureTests/
│       ├── DirectoryMatcherTests.swift
│       ├── OCRFieldExtractionTests.swift
│       ├── ResourceDecodingTests.swift
│       ├── SampleDirectoryTests.swift
│       └── Fixtures/
│           └── sm_directory_sample.json
├── MineOpsCompanionUITests/
│   └── MineOpsCompanionUITests.swift
├── Config/
│   ├── Shared.xcconfig
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   ├── Tests.xcconfig
│   └── MineOpsCompanion.entitlements
├── .github/workflows/
│   └── ios-ci.yml
├── scripts/
│   ├── format.sh
│   └── lint.sh
├── fastlane/
│   └── Fastfile
├── Gemfile
└── .swift-format
```OCRTextHeuristics
│   │   │   └── OCRReviewView.swift     # Manager list with CRUD UI
│   │   ├── Resources/
│   │   │   └── sm_directory.json       # Super Manager directory
│   │   ├── Strategy/
│   │   │   ├── StrategyEngine.swift    # Boost calculations
---

## 5. Key Implementation Details

### OCR Pipeline
**OCRProcessor** (`OCR/OCRProcessor.swift`):
- VisionKit `VNRecognizeTextRequest` with `.accurate` recognition level
- Processes batch images asynchronously
- Integrates **DirectoryMatcher** for name resolution (0.30 Jaccard threshold)
- Integrates **OCRFieldExtraction** for 13-field parsing (rarity, role, stars, active/passive stats)
- Merges results into `OCRReviewViewModel` with deduplication by identityKey

**DirectoryMatcher** (`OCR/OCRLevelParser.swift`):
- `bestMatch(in:directory:)`: Scans every OCR line for highest scoring directory entry
- Scoring: 1.0 for substring containment, else token-based Jaccard similarity
- Threshold: 0.30 minimum score required for match
- Fallback: `OCRTextHeuristics.guessDisplayName(from:)` filters keywords/numbers

**OCRFieldExtraction** (`Models/OCRResult.swift`):
- Regex-based extractor parsing 13 fields:
  - Basic: `rarity` (Common/Rare/Epic/Legendary), `role` (Mine/Warehouse/Transport/Elevator), `stars` (1-6)
  - Active: `effect`, `multiplier`, `durationSeconds`, `cooldownSeconds`
  - Passive: `effect`, `multiplier`, `durationSeconds`
  - Actions: `hasLevelUp`, `hasPromote`, `hasRankUp` booleans
- `durationToSeconds(value:unit:)`: Converts "5m" → 300, "30m" → 1800
- Section isolation: `section(containing:from:)` extracts Active/Passive blocks

### Manager Database
**RecognizedSM** (`Models/OCRResult.swift`):
- Domain model with `id`, `image`, `displayName`, `directoryEntry`, `stats`, plus 6 extracted fields
- Nested structs: `ActiveInfo`, `PassiveInfo`, `ActionFlags`
- `updatingMetadata(...)`: Immutable update preserving id/image
- `identityKey`: Canonical identifier for deduplication (directoryEntry.name or displayName)

**Persistence** (`Data/Persistence.swift`):
- Saves to `ApplicationSupport/MineOpsCompanion/recognized_sms.json`
- Images stored as `{uuid}.png` in same directory
- `StoredRecognizedSM`: Codable with conditional encoding (skips empty nested data)
- Automatic orphan cleanup: Prunes PNG files not referenced in JSON

**OCRReviewView** (`OCR/OCRReviewView.swift`):
- PhotosPicker for batch image selection
- List with swipe-to-delete and EditButton
- **ManagerEditSheet**: Full CRUD form with 4 sections (Basics, Active, Passive, Actions)
- **RecognizedSMEditDraft**: Bidirectional conversion with duration/multiplier parsing
**Code Formatting** (`.swift-format`):
- 2-space indentation, 100-char line length
- Enforces ordered imports, no semicolons, extensive rule set
- Run via `swift format -i -r` or `scripts/format.sh`

## 6. Development Workflowdling and batch progress UI.  
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

*Author: Yancy Shepherd  · Internal Project: MineOps Companion · 2025-10-27*---

## 6. Development Workflow

### Adding New Features
1. **Create files in SPM package**: `MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/`
2. **Make types public**: Expose to app target with `public` access modifiers
3. **Add tests**: Create test files in `MineOpsCompanionPackage/Tests/MineOpsCompanionFeatureTests/`
4. **Run tests**: `Cmd+U` or `bundle exec fastlane test`
5. **Format code**: `./scripts/format.sh` before committing

### Debugging OCR Issues
- **Enable debug display**: OCRReviewView shows 13 extracted fields per manager
- **Check directory matching**: DirectoryMatcher logs score calculations
- **Inspect persistence**: `~/Library/Application Support/MineOpsCompanion/recognized_sms.json`
- **View raw OCR text**: Add breakpoint in `OCRProcessor.processImages(_:)`

### Modifying Build Settings
- **Bundle ID / Version**: Edit `Config/Shared.xcconfig`
- **Debug flags**: Edit `Config/Debug.xcconfig`
- **Release optimizations**: Edit `Config/Release.xcconfig`
- **App capabilities**: Edit `Config/MineOpsCompanion.entitlements` (XML)

### Adding Dependencies
Edit `MineOpsCompanionPackage/Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/example/SomePackage", from: "1.0.0")
],
targets: [
    .target(
        name: "MineOpsCompanionFeature",
        dependencies: ["SomePackage"],
        resources: [.process("Resources")]
    ),
]
```---

## 7. Troubleshooting

### Build Failures
- **Swift version mismatch**: Ensure Xcode 16+ with Swift 6.1
- **Missing workspace**: Always open `.xcworkspace`, not `.xcodeproj`
- **Package resolution**: `File → Packages → Reset Package Caches` in Xcode
- **Code signing**: Simulator builds don't require signing (CI uses `CODE_SIGNING_REQUIRED=NO`)

### Test Failures
- **Simulator not booted**: Xcode auto-boots, or run `xcrun simctl boot "iPhone 16"`
- **Resource not found**: Check `Package.swift` has `resources: [.process("Resources")]`
- **Fixture issues**: Verify `Fixtures/sm_directory_sample.json` exists in test target

### OCR Not Working
- **Photos permission**: Check `Info.plist` has `NSPhotoLibraryUsageDescription`
- **Image quality**: Use high-res screenshots for better accuracy
- **Text recognition**: VisionKit requires iOS 13+, `.accurate` level needs good lighting

### Persistence Issues
- **Data not saving**: Check `~/Library/Application Support/MineOpsCompanion/` permissions
- **Orphan images**: Run app to trigger automatic cleanup on next save
- **Corrupt JSON**: Delete `recognized_sms.json` and re-import screenshots

---

## 8. Future Enhancements (Roadmap)
- **Snapshot History**: Store OCR results with timestamps for trend analysis
- **Export Formats**: Add JSON, CSV, Markdown export options
- **Advanced Filtering**: Filter managers by department, rarity, level range
- **Image Hash Deduplication**: Prevent duplicate imports via perceptual hashing
- **CloudKit Sync**: Optional iCloud backup of manager database
- **Widgets**: Home screen widget showing top active managers

---

*Author: Yancy Shepherd  · Project: MineOps Companion · Updated: 2025-10-29*- **Corrupt JSON**: Delete `recognized_sms.json` and re-import screenshots

## 8. Future Enhancements (Roadmap)