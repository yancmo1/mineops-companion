import SwiftUI

struct MineOpsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var review: OCRReviewViewModel

    @State private var existingKeySuffix: String?
    @State private var isKeySet = false

    @State private var draftKey = ""
    @State private var revealKey = false

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    @State private var confirmClearAllData = false

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenAI") {
                    VStack(alignment: .leading, spacing: 8) {
                        if isKeySet {
                            Text("API key is set" + (existingKeySuffix.map { " (…\($0))" } ?? ""))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("openAIKeyStatusSet")
                        } else {
                            Text("API key not set")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("openAIKeyStatusMissing")
                        }

                        Text("This key is stored securely on-device (Keychain). It is required for Strategy Builder and manager detection.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            if revealKey {
                                TextField("sk-…", text: $draftKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .textContentType(.password)
                                    .accessibilityIdentifier("openAIKeyField")
                            } else {
                                SecureField("sk-…", text: $draftKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .textContentType(.password)
                                    .accessibilityIdentifier("openAIKeyField")
                            }

                            Button(revealKey ? "Hide" : "Show") {
                                revealKey.toggle()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("toggleRevealOpenAIKeyButton")
                        }

                        HStack {
                            Button {
                                Task { await saveKey() }
                            } label: {
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text("Save")
                                }
                            }
                            .disabled(isSaving || draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("saveOpenAIKeyButton")

                            Button(role: .destructive) {
                                Task { await clearKey() }
                            } label: {
                                Text("Clear")
                            }
                            .disabled(isSaving || !isKeySet)
                            .accessibilityIdentifier("clearOpenAIKeyButton")

                            Spacer()
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("openAIKeyError")
                    }

                    if let successMessage {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("openAIKeySuccess")
                    }
                }

                Section("Privacy") {
                    Text("Never share your API key. For TestFlight, each tester must enter their own key.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    Button(role: .destructive) {
                        confirmClearAllData = true
                    } label: {
                        Text("Clear All Data")
                    }
                    .accessibilityIdentifier("clearAllDataButton")

                    Text("Clears imported managers, snapshots, and strategy history/cache. Does not clear your OpenAI API key.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settingsDoneButton")
                }
            }
            .task {
                await refreshStatus()
            }
            .confirmationDialog(
                "Clear all data?",
                isPresented: $confirmClearAllData,
                titleVisibility: .visible
            ) {
                Button("Clear All Data", role: .destructive) {
                    Task {
                        AppDataResetter.clearAllUserData()
                        review.reload()
                        confirmClearAllData = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all imported Super Managers, snapshots, and saved strategy history/cache from this device.")
            }
        }
    }

    @MainActor
    private func refreshStatus() async {
        let key = await OpenAIKeyStore.shared.loadKey()
        if let key {
            isKeySet = true
            existingKeySuffix = String(key.suffix(4))
        } else {
            isKeySet = false
            existingKeySuffix = nil
        }
    }

    @MainActor
    private func saveKey() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        do {
            try await OpenAIKeyStore.shared.saveKey(draftKey)
            draftKey = ""
            successMessage = "Saved."
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func clearKey() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        await OpenAIKeyStore.shared.clearKey()
        draftKey = ""
        successMessage = "Cleared."
        await refreshStatus()
    }
}

#Preview("Settings") {
    MineOpsSettingsView()
        .preferredColorScheme(.dark)
}
