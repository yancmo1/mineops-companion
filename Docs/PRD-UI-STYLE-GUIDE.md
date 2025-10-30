# MineOps Companion – UI/UX Style & Architecture PRD  
*(For VS Code Agent + SwiftUI Dev Enforcement)*

## 🎯 Purpose
This PRD defines the **unified design system**, **file structure**, and **SwiftUI styling standards** for the MineOps Companion app.  
The goal is to ensure all screens—Command Center, Pocket Assistant, Blueprint, Chronicle, and Orbit—share a cohesive dark-neon style and layout flow.

---

## 🧩 Folder Architecture

```
MineOpsCompanion/
│
├── Theme/
│   ├── ColorTheme.swift         # Centralized color definitions (global)
│   └── Typography.swift         # (Optional) Shared font styles & modifiers
│
├── App/
│   ├── CommandCenterView.swift  # Dashboard (Home)
│   ├── PocketAssistantView.swift # Stat Cards, summaries
│   ├── BlueprintView.swift      # Mine layout visualization
│   ├── ChronicleView.swift      # Formerly “Strategies”, strategy builder
│   ├── OrbitView.swift          # Data sync / export / import view
│   └── UIComponents/            # Shared reusable SwiftUI components
│       ├── BoostBar.swift
│       ├── QuickStat.swift
│       ├── MineOpsButton.swift
│       └── CardContainer.swift
│
├── App/PreviewLayouts/
│   └── UIPreviews.swift         # Aggregated previews for all major views
│
├── Config/
│   └── AppSettings.swift        # Placeholder for persistence & user defaults
│
└── Tests/
    └── MineOpsCompanionUITests/
```

✅ Agent should **move duplicate visual components** (BoostBar, QuickStat, etc.) to `/UIComponents`.  
✅ Any duplicate color extension must be removed—keep only `ColorTheme.swift`.

---

## 🎨 Visual Design System

### 1. Colors
Use **ColorTheme.swift** as the single source of truth:
```swift
extension Color {
    static let mineDark = Color(red: 0.03, green: 0.07, blue: 0.11)
    static let mineDarkCard = Color(red: 0.05, green: 0.1, blue: 0.15)
    static let mineDarkLight = Color(red: 0.07, green: 0.14, blue: 0.2)
    static let accentCyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    static let accentOrange = Color(red: 1.0, green: 0.5, blue: 0.1)
}
```
All `.cyan` → `.accentCyan`  
All `.black` backgrounds → `.mineDark`

---

### 2. Typography
**Headings:** `.font(.title.bold())` or `.font(.title2.bold())`  
**Labels:** `.font(.headline)`  
**Captions:** `.font(.caption).foregroundColor(.gray)`  
**Highlight values:** `.font(.headline.bold()).foregroundColor(.accentCyan)`

---

### 3. Cards & Panels
- Always use a rounded rectangle background:
  ```swift
  .background(Color.mineDarkCard)
  .clipShape(RoundedRectangle(cornerRadius: 12))
  .shadow(color: .accentCyan.opacity(0.15), radius: 6)
  ```
- Borders should use `.overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentCyan.opacity(0.6), lineWidth: 1.5))`.

---

### 4. Buttons
Global style:
```swift
MineOpsButton(label: "Select Screenshots", icon: "photo.on.rectangle")
```
Implementation in `/UIComponents/MineOpsButton.swift`:
```swift
import SwiftUI

struct MineOpsButton: View {
    let label: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.headline)
                .foregroundColor(.accentCyan)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.mineDarkLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentCyan.opacity(0.8), lineWidth: 1))
        }
    }
}
```

---

## 🧭 Navigation & Tabs

Main tab layout is defined in `MineOpsDashboardViews.swift`:

```swift
struct MineOpsDashboardViews: View {
    var body: some View {
        TabView {
            CommandCenterView()
                .tabItem { Label("Command", systemImage: "gearshape.2.fill") }

            PocketAssistantView()
                .tabItem { Label("Assistant", systemImage: "brain.head.profile") }

            BlueprintView()
                .tabItem { Label("Blueprint", systemImage: "map.fill") }

            ChronicleView()
                .tabItem { Label("Strategies", systemImage: "book.fill") }

            OrbitView()
                .tabItem { Label("Orbit", systemImage: "globe.americas.fill") }
        }
        .tint(.accentCyan)
        .background(Color.mineDark)
    }
}
```

---

## 💡 VS Code Agent Tasks

The agent should:

1. **Refactor:**  
   Move any duplicated components (BoostBar, QuickStat, etc.) into `UIComponents`.

2. **Fix Imports:**  
   Add `import SwiftUI` to all Swift files using SwiftUI views.  
   Remove redundant `extension Color` declarations.

3. **Normalize Color Usage:**  
   Replace all `.black`, `.cyan`, `.orange`, etc., with shared theme colors.

4. **Preview Verification:**  
   Ensure each SwiftUI file includes a valid preview block:
   ```swift
   #Preview { CommandCenterView() }
   ```

5. **Canvas Verification:**  
   Run `Cmd + Option + P` to resume the Canvas and confirm visual consistency.

6. **File Check:**  
   Ensure each file lives in the folder specified above, with exact casing.

---

## 🚀 Target Outcome

After implementing this PRD, the project should:
- Compile cleanly without any “invalid redeclaration” errors.
- Render all views in SwiftUI Canvas correctly.
- Maintain consistent neon-dark styling across all pages.
- Be modular, so each view can evolve independently.

---

**End of PRD**