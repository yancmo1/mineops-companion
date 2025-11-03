# MineOpsCompanion - iOS App

A modern iOS application using a **workspace + SPM package** architecture for clean separation between app shell and feature code.

## AI Assistant Rules Files

This template includes **opinionated rules files** for popular AI coding assistants. These files establish coding standards, architectural patterns, and best practices for modern iOS development using the latest APIs and Swift features.

### Included Rules Files
- **Claude Code**: `CLAUDE.md` - Claude Code rules
- **Cursor**: `.cursor/*.mdc` - Cursor-specific rules
- **GitHub Copilot**: `.github/copilot-instructions.md` - GitHub Copilot rules

### Customization Options
These rules files are **starting points** - feel free to:
- ✅ **Edit them** to match your team's coding standards
- ✅ **Delete them** if you prefer different approaches
- ✅ **Add your own** rules for other AI tools
- ✅ **Update them** as new iOS APIs become available

### What Makes These Rules Opinionated
- **No ViewModels**: Embraces pure SwiftUI state management patterns
- **Swift 6+ Concurrency**: Enforces modern async/await over legacy patterns
- **Latest APIs**: Recommends iOS 18+ features with optional iOS 26 guidelines
- **Testing First**: Promotes Swift Testing framework over XCTest
- **Performance Focus**: Emphasizes @Observable over @Published for better performance

**Note for AI assistants**: You MUST read the relevant rules files before making changes to ensure consistency with project standards.

## Project Architecture

```
MineOpsCompanion/
├── MineOpsCompanion.xcworkspace/              # Open this file in Xcode
├── MineOpsCompanion.xcodeproj/                # App shell project
├── MineOpsCompanion/                          # App target (minimal)
│   ├── Assets.xcassets/                # App-level assets (icons, colors)
│   ├── MineOpsCompanionApp.swift              # App entry point
│   └── MineOpsCompanion.xctestplan            # Test configuration
├── MineOpsCompanionPackage/                   # 🚀 Primary development area
│   ├── Package.swift                   # Package configuration
│   ├── Sources/MineOpsCompanionFeature/       # Your feature code
│   └── Tests/MineOpsCompanionFeatureTests/    # Unit tests
└── MineOpsCompanionUITests/                   # UI automation tests
```

## Key Architecture Points

### Workspace + SPM Structure
- **App Shell**: `MineOpsCompanion/` contains minimal app lifecycle code
- **Feature Code**: `MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/` is where most development happens
- **Separation**: Business logic lives in the SPM package, app target just imports and displays it

### Buildable Folders (Xcode 16)
- Files added to the filesystem automatically appear in Xcode
- No need to manually add files to project targets
- Reduces project file conflicts in teams

## Current Implementation

### Feature Overview
**MineOps Companion** is a production-ready Super Manager database app with comprehensive OCR extraction, CRUD operations, and strategic analysis.

### Core Features
- **Image Intake & OCR**: Batch photo import with VisionKit text recognition
- **Field Extraction**: Parses 13+ data points per manager (rarity, role, stars, active/passive abilities, cooldowns, action flags)
- **Manager Database**: Full CRUD operations with swipe-to-delete and edit sheets
- **Dashboard**: Department coverage summaries and readiness gauges
- **Strategy Analysis**: Boost calculations and optimal manager recommendations
- **Persistence**: JSON + PNG storage in ApplicationSupport with automatic cleanup

### Architecture Patterns
- **Model-View (MV)**: No ViewModels, uses `@Observable`, `@State`, `@Environment`
- **Swift Concurrency**: `@MainActor` for UI/persistence, `async/await` for OCR processing
- **Actor Isolation**: All concurrency follows Swift 6 strict concurrency rules
- **Testing**: Swift Testing framework (`@Test`, `#expect`) with test fixtures

### Key Components
- **OCRProcessor**: VisionKit integration with accurate recognition level
- **DirectoryMatcher**: Token-based Jaccard similarity (0.30 threshold) + substring matching
- **OCRFieldExtraction**: Regex-based parser for all PRD fields (rarity, role, active/passive stats)
- **RecognizedSM**: Domain model with nested structs (ActiveInfo, PassiveInfo, ActionFlags)
- **Persistence**: StoredRecognizedSM codable with conditional encoding (skips empty data)
- **OCRReviewView**: Manager list with PhotosPicker, edit sheets, debug field display
- **CommandCenterViewV2**: Department summaries with canonical role mapping
- **StrategySummaryView**: Strategic recommendations based on manager stats

## CI / Formatting / Fastlane

### Continuous Integration
- **Workflow**: `.github/workflows/ios-ci.yml` runs on push/PR to main/develop
- **Runner**: macOS 14 with Xcode 16
- **Jobs**: Build + test on iPhone 16 simulator (iOS 18.0)
- **Test Plan**: Uses `MineOpsCompanion.xctestplan` for coordinated test execution

### Code Formatting
- **Config**: `.swift-format` defines formatting rules (2-space indent, 100 char line length)
- **Script**: `scripts/format.sh` formats all Swift files in Sources/ and Tests/
- **Manual**: `swift format -i -r MineOpsCompanionPackage/Sources MineOpsCompanionPackage/Tests`
- **Pre-commit Hook**: Optionally run `scripts/format.sh` in git hooks

### Fastlane
- **Setup**: `bundle install` to install Fastlane and dependencies
- **Build**: `bundle exec fastlane build` - builds app for simulator
- **Test**: `bundle exec fastlane test` - runs all tests with code coverage
- **Format**: `bundle exec fastlane format` - formats code via script

## Development Notes

### Code Organization
Most development happens in `MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/` - organize your code as you prefer.

Current structure:
```
Sources/MineOpsCompanionFeature/
├── ContentView.swift              # Root TabView coordinator
├── Data/
│   └── Persistence.swift          # JSON + image storage
├── Export/
│   └── ExportManager.swift        # CSV export utilities
├── Models/
│   ├── OCRResult.swift            # OCR domain models (RecognizedSM, OCRFieldExtraction)
│   └── SuperManager.swift         # Directory models (SMDirectoryEntry, SMStats)
├── OCR/
│   ├── OCRProcessor.swift         # VisionKit integration
│   ├── OCRLevelParser.swift       # Directory matching and heuristics
│   └── OCRReviewView.swift        # Manager list with CRUD UI
├── Resources/
│   └── sm_directory.json          # Super Manager directory data
├── Strategy/
│   ├── StrategyEngine.swift       # Boost calculations
│   └── StrategySummaryView.swift  # Strategic recommendations
└── Support/
    └── ResourceLoader.swift       # Bundle resource utilities
```

### Public API Requirements
Types exposed to the app target need `public` access:
```swift
public struct NewView: View {
    public init() {}
    
    public var body: some View {
        // Your view code
    }
}
```

### Adding Dependencies
Edit `MineOpsCompanionPackage/Package.swift` to add SPM dependencies:
```swift
dependencies: [
    .package(url: "https://github.com/example/SomePackage", from: "1.0.0")
],
targets: [
    .target(
        name: "MineOpsCompanionFeature",
        dependencies: ["SomePackage"]
    ),
]
```

### Test Structure
- **Unit Tests**: `MineOpsCompanionPackage/Tests/MineOpsCompanionFeatureTests/` (Swift Testing framework)
- **UI Tests**: `MineOpsCompanionUITests/` (XCUITest framework)
- **Test Plan**: `MineOpsCompanion.xctestplan` coordinates all tests

## Configuration

### XCConfig Build Settings
Build settings are managed through **XCConfig files** in `Config/`:
- `Config/Shared.xcconfig` - Common settings (bundle ID, versions, deployment target)
- `Config/Debug.xcconfig` - Debug-specific settings  
- `Config/Release.xcconfig` - Release-specific settings
- `Config/Tests.xcconfig` - Test-specific settings

### Entitlements Management
App capabilities are managed through a **declarative entitlements file**:
- `Config/MineOpsCompanion.entitlements` - All app entitlements and capabilities
- AI agents can safely edit this XML file to add HealthKit, CloudKit, Push Notifications, etc.
- No need to modify complex Xcode project files

### Asset Management
- **App-Level Assets**: `MineOpsCompanion/Assets.xcassets/` (app icon, accent color)
- **Feature Assets**: Add `Resources/` folder to SPM package if needed

### SPM Package Resources
To include assets in your feature package:
```swift
.target(
    name: "MineOpsCompanionFeature",
    dependencies: [],
    resources: [.process("Resources")]
)
```

### Generated with XcodeBuildMCP
This project was scaffolded using [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP), which provides tools for AI-assisted iOS development workflows.