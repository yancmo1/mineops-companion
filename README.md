# MineOpsCompanion - iOS App

A modern iOS application for managing Super Managers in Idle Miner Tycoon. Uses OCR to extract manager data from screenshots and provides strategic insights for deployment optimization.

## Features

- **OCR Import**: Extract 13+ data points from screenshots (name, department, rarity, stars, active/passive abilities, action buttons)
- **Manager Database**: Full CRUD operations with swipe-to-delete and edit sheets
- **Command Center Dashboard**: Department coverage and readiness metrics
- **Strategy View**: Deployment recommendations (in development)
- **Debug Visibility**: All extracted OCR fields shown for validation

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

## Development Notes

### Code Organization
Most development happens in `MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/` - organize your code as you prefer.

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
## CI / Formatting / Fastlane

### Continuous Integration
GitHub Actions workflow (`.github/workflows/ios-ci.yml`) runs on every push/PR:
- Builds on macOS 14 with Xcode 16
- Runs full test suite on iPhone 16 simulator
- Uploads test results as artifacts

### Code Formatting
Swift code is formatted using `swift-format`:
```bash
# Install swift-format
brew install swift-format

# Format all code
./scripts/format.sh

# Check formatting (CI mode)
./scripts/format.sh --check
```

Configuration: `.swift-format` (2-space indent, 120 line length)

### Fastlane
Automation lanes for build/test/format:
```bash
# Install dependencies
bundle install

# Build for simulator
bundle exec fastlane build

# Run tests with coverage
bundle exec fastlane test

# Format code
bundle exec fastlane format

# Check formatting
bundle exec fastlane format_check
```

## Development Workflow

1. Open `MineOpsCompanion.xcworkspace` in Xcode
2. Make changes in `MineOpsCompanionPackage/Sources/`
3. Write tests in `MineOpsCompanionPackage/Tests/`
4. Run tests (Cmd+U)
5. Format code: `./scripts/format.sh`
6. Commit and push (CI will validate)

### Generated with XcodeBuildMCP
This project was scaffolded using [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP), which provides tools for AI-assisted iOS development workflows.
    name: "MineOpsCompanionFeature",
    dependencies: [],
    resources: [.process("Resources")]
)
```

### Generated with XcodeBuildMCP
This project was scaffolded using [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP), which provides tools for AI-assisted iOS development workflows.