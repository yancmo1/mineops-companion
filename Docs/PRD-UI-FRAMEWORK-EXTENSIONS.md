# MineOps Companion – UI Framework Extensions & Component System  
*(For VS Code Agent implementation – phase 2 of UI standardization)*

---

## 🎯 Objective
This document extends the **UI Style Guide PRD** with live code scaffolds and conventions.  
Once these files are added, the MineOps Companion UI will be fully modular, theme-driven, and easily scalable for future screens and animations.

---

## 🧩 Folder Targets

Ensure this structure is in place:

```
MineOpsCompanion/
│
├── Theme/
│   ├── ColorTheme.swift
│   ├── Typography.swift
│   └── LayoutConstants.swift
│
├── App/
│   ├── CommandCenterView.swift
│   ├── PocketAssistantView.swift
│   ├── BlueprintView.swift
│   ├── ChronicleView.swift
│   ├── OrbitView.swift
│   └── UIComponents/
│       ├── MineOpsButton.swift
│       ├── CardContainer.swift
│       ├── QuickStat.swift
│       └── BoostBar.swift
│
└── App/PreviewLayouts/
    └── UIPreviews.swift
```

---

## 🧱 Core Theme Files

### 1. 📄 `Typography.swift`

```swift
import SwiftUI

struct MineOpsFont {
    static let heading = Font.system(size: 24, weight: .bold, design: .rounded)
    static let subheading = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 13, weight: .regular, design: .rounded)
}

extension View {
    func mineOpsHeadingStyle() -> some View {
        self.font(MineOpsFont.heading)
            .foregroundColor(.accentCyan)
    }

    func mineOpsCardTitle() -> some View {
        self.font(MineOpsFont.subheading)
            .foregroundColor(.white)
    }

    func mineOpsBody() -> some View {
        self.font(MineOpsFont.body)
            .foregroundColor(.white.opacity(0.9))
    }

    func mineOpsCaption() -> some View {
        self.font(MineOpsFont.caption)
            .foregroundColor(.gray)
    }
}
```

---

### 2. 📄 `LayoutConstants.swift`

```swift
import Foundation
import SwiftUI

struct MineOpsLayout {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
}
```

---

## 🧰 Shared UI Components

### 1. 📄 `CardContainer.swift`
```swift
import SwiftUI

struct CardContainer<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .mineOpsCardTitle()
                    .padding(.bottom, 4)
            }
            content
        }
        .padding()
        .background(Color.mineDarkCard)
        .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius)
                .stroke(Color.accentCyan.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.accentCyan.opacity(0.1), radius: 6)
    }
}
```

---

### 2. 📄 `MineOpsButton.swift`
```swift
import SwiftUI

struct MineOpsButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label)
                    .font(.headline)
            }
            .foregroundColor(.accentCyan)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.mineDarkLight)
            .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius)
                    .stroke(Color.accentCyan.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
```

---

### 3. 📄 `QuickStat.swift`
```swift
import SwiftUI

struct QuickStat: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .mineOpsCaption()
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.mineDarkCard)
        .clipShape(RoundedRectangle(cornerRadius: MineOpsLayout.cornerRadius))
        .shadow(color: color.opacity(0.15), radius: 5)
    }
}
```

---

### 4. 📄 `BoostBar.swift`
```swift
import SwiftUI

struct BoostBar: View {
    let label: String
    let boostValue: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .mineOpsCaption()
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.mineDarkLight)
                    .frame(height: 8)
                Capsule()
                    .fill(color)
                    .frame(width: CGFloat(boostValue), height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}
```

---

## 🧠 Agent Implementation Logic

The agent should perform the following automatically:

1. **Create any missing folders**:  
   `/Theme` and `/App/UIComponents`

2. **Validate imports**:  
   Every SwiftUI file must start with `import SwiftUI`.

3. **Replace colors & text styling**:  
   - `.black` → `.mineDark`
   - `.cyan` → `.accentCyan`
   - `.orange` → `.accentOrange`
   - Use typography modifiers (`mineOpsHeadingStyle()`, etc.) instead of inline fonts.

4. **Rebuild views**:  
   - Wrap UI groups in `CardContainer`.
   - Use `QuickStat` for dashboard metrics.
   - Use `BoostBar` for progress-style visuals.
   - Buttons should use `MineOpsButton`.

5. **Preview verification**:  
   - Each file should end with:
     ```swift
     #Preview { <ViewName>() }
     ```

6. **Canvas test**:  
   Run `Cmd + Option + P` to confirm that all previews render with no layout warnings.

7. **Consistency check**:  
   Ensure corner radius and shadow values are consistent across all screens.

---

## 🚀 End Goal

After the agent applies both PRDs:
- The app compiles without duplicate declarations or import errors.
- All views share unified colors, fonts, and rounded-card styling.
- Each screen feels part of the same neon-dark ecosystem.
- The design is modular, previewable, and extendable for new features.

---

**End of Document**