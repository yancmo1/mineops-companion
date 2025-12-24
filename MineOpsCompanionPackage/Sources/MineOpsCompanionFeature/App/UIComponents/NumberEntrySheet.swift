import SwiftUI

/// A lightweight number entry sheet for replacing +/- only controls.
struct NumberEntrySheet: View {
    let title: String
    let currentValue: Int
    let range: ClosedRange<Int>
    let accessibilityIdentifier: String?
    let onCommit: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(
        title: String,
        currentValue: Int,
        range: ClosedRange<Int>,
        accessibilityIdentifier: String? = nil,
        onCommit: @escaping (Int) -> Void
    ) {
        self.title = title
        self.currentValue = currentValue
        self.range = range
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onCommit = onCommit
        // Start blank so the first digit replaces the existing value (no delete required).
        self._text = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text(displayText)
                        .font(.system(size: 42, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isShowingPlaceholder ? Color.white.opacity(0.45) : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .accessibilityIdentifier(fieldIdentifier)

                    Text("Allowed: \(range.lowerBound)–\(range.upperBound)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                NumericKeypad(
                    text: $text,
                    clearIdentifier: clearIdentifier,
                    deleteIdentifier: deleteIdentifier,
                    keyIdentifierPrefix: keyIdentifierPrefix
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(cancelIdentifier)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commit()
                    }
                    .accessibilityIdentifier(doneIdentifier)
                }
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnly = trimmed.filter { $0.isNumber }
        let parsed = Int(digitsOnly) ?? currentValue
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        onCommit(clamped)
        dismiss()
    }

    private var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnly = trimmed.filter { $0.isNumber }
        return digitsOnly.isEmpty ? String(currentValue) : digitsOnly
    }

    private var isShowingPlaceholder: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.filter { $0.isNumber }.isEmpty
    }

    private var baseIdentifier: String? { accessibilityIdentifier }

    private var fieldIdentifier: String {
        baseIdentifier.map { "\($0)_field" } ?? "numberEntry_field"
    }

    private var cancelIdentifier: String {
        baseIdentifier.map { "\($0)_cancel" } ?? "numberEntry_cancel"
    }

    private var doneIdentifier: String {
        baseIdentifier.map { "\($0)_done" } ?? "numberEntry_done"
    }
    private var clearIdentifier: String {
        baseIdentifier.map { "\($0)_clear" } ?? "numberEntry_clear"
    }

    private var deleteIdentifier: String {
        baseIdentifier.map { "\($0)_delete" } ?? "numberEntry_delete"
    }

    private var keyIdentifierPrefix: String {
        baseIdentifier.map { "\($0)_key" } ?? "numberEntry_key"
    }
}

private struct NumericKeypad: View {
    @Binding var text: String
    let clearIdentifier: String
    let deleteIdentifier: String
    let keyIdentifierPrefix: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9"], id: \.self) { digit in
                keyButton(label: digit) {
                    appendDigit(digit)
                }
                .accessibilityIdentifier("\(keyIdentifierPrefix)_\(digit)")
            }

            keyButton(label: "Clear", systemImage: "xmark.circle") {
                text = ""
            }
            .accessibilityIdentifier(clearIdentifier)

            keyButton(label: "0") {
                appendDigit("0")
            }
            .accessibilityIdentifier("\(keyIdentifierPrefix)_0")

            keyButton(label: "Del", systemImage: "delete.left") {
                deleteLast()
            }
            .accessibilityIdentifier(deleteIdentifier)
        }
        .padding(.top, 4)
    }

    private func appendDigit(_ digit: String) {
        let digitsOnly = text.filter { $0.isNumber }
        // Prevent absurdly long values, but keep it generous.
        guard digitsOnly.count < 6 else { return }
        text = digitsOnly + digit
    }

    private func deleteLast() {
        var digitsOnly = text.filter { $0.isNumber }
        _ = digitsOnly.popLast()
        text = digitsOnly
    }

    @ViewBuilder
    private func keyButton(label: String, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.mineDarkLight.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentCyan.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
