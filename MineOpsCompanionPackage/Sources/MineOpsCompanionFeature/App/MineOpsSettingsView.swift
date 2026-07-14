import SwiftUI

struct MineOpsSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var existingKeySuffix: String?
    @State private var isKeySet = false

    @State private var draftKey = ""
    @State private var revealKey = false

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    @State private var confirmClearAllData = false

    // AI Provider settings
    @State private var selectedProvider: AIProvider = AIProviderConfig.shared.activeProvider
    @State private var deepSeekKey = ""
    @State private var openAIModel = AIProviderConfig.shared.openAIModel
    @State private var deepSeekModel = AIProviderConfig.shared.deepSeekModel
    @State private var revealDeepSeek = false
    
    // Kolibri settings
    @State private var kolibriId = ""
    @State private var kolibriAuthToken = ""
    @State private var kolibriSaveGameKey = "0"
    @State private var revealAuthToken = false

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedProvider) { _, newValue in
                        AIProviderConfig.shared.activeProvider = newValue
                    }

                    if selectedProvider == .openAI {
                        openAISection
                    } else {
                        deepSeekSection
                    }
                }
                
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
                    Text("Never share your API keys. For TestFlight, each tester must enter their own key.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                Section("Kolibri API") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect to Kolibri Game Services to automatically sync your game data instead of using OCR.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !KolibriCredentialsStore.shared.hasCredentials {
                            Text("Credentials not configured")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        } else {
                            Text("Credentials configured")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // Accept either a raw Kolibri UUID or a pasted debug string containing a UUID.
                        TextField("Paste full debug ID or Kolibri UUID", text: $kolibriId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .accessibilityIdentifier("kolibriIdField")
                        
                        HStack {
                            if revealAuthToken {
                                TextField("Authorization Token", text: $kolibriAuthToken)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .textContentType(.password)
                                    .accessibilityIdentifier("kolibriAuthTokenField")
                            } else {
                                SecureField("Authorization Token", text: $kolibriAuthToken)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .textContentType(.password)
                                    .accessibilityIdentifier("kolibriAuthTokenField")
                            }
                            
                            Button(revealAuthToken ? "Hide" : "Show") {
                                revealAuthToken.toggle()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("toggleRevealAuthTokenButton")
                        }
                        
                        TextField("Save Game Key", text: $kolibriSaveGameKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .accessibilityIdentifier("kolibriSaveGameKeyField")
                        
                        HStack {
                            Button("Save Credentials") {
                                saveKolibriCredentials()
                            }
                            .disabled(kolibriId.isEmpty || kolibriAuthToken.isEmpty)
                            .accessibilityIdentifier("saveKolibriCredsButton")
                            
                            Button(role: .destructive) {
                                clearKolibriCredentials()
                            } label: {
                                Text("Clear")
                            }
                            .disabled(!KolibriCredentialsStore.shared.hasCredentials)
                            .accessibilityIdentifier("clearKolibriCredsButton")
                            
                            Spacer()
                        }
                    }
                    
                    Text("Credentials are stored securely on-device (Keychain). Paste a full debug ID or the Kolibri UUID above and press Save.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Models") {
                    if selectedProvider == .openAI {
                        TextField("Model (e.g. gpt-4o-mini)", text: $openAIModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .onChange(of: openAIModel) { _, newValue in
                                AIProviderConfig.shared.openAIModel = newValue
                            }
                    } else {
                        TextField("Model (e.g. deepseek-chat)", text: $deepSeekModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .onChange(of: deepSeekModel) { _, newValue in
                                AIProviderConfig.shared.deepSeekModel = newValue
                            }
                    }
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
                loadKolibriCredentials()
            }
            .confirmationDialog(
                "Clear all data?",
                isPresented: $confirmClearAllData,
                titleVisibility: .visible
            ) {
                Button("Clear All Data", role: .destructive) {
                    Task {
                        AppDataResetter.clearAllUserData()
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

    // MARK: - OpenAI Section

    @ViewBuilder
    private var openAISection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OpenAI API key")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isKeySet {
                Text("Key is set" + (existingKeySuffix.map { " (…\($0))" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("Key not set")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
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

    // MARK: - DeepSeek Section

    @ViewBuilder
    private var deepSeekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DeepSeek API key")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if AIProviderConfig.shared.hasKey(for: .deepSeek) {
                Text("Key is set")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("Key not set")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }

        HStack {
            if revealDeepSeek {
                TextField("sk-…", text: $deepSeekKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            } else {
                SecureField("sk-…", text: $deepSeekKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Button(revealDeepSeek ? "Hide" : "Show") {
                revealDeepSeek.toggle()
            }
            .buttonStyle(.bordered)
        }

        HStack {
            Button("Save") {
                AIProviderConfig.shared.saveDeepSeekKey(deepSeekKey)
                deepSeekKey = ""
                successMessage = "DeepSeek key saved."
            }
            .disabled(deepSeekKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(role: .destructive) {
                AIProviderConfig.shared.clearDeepSeekKey()
                successMessage = "DeepSeek key cleared."
            } label: {
                Text("Clear")
            }
            .disabled(!AIProviderConfig.shared.hasKey(for: .deepSeek))
        }
    }
    
    // MARK: - Kolibri Credentials
    
    private func loadKolibriCredentials() {
        let store = KolibriCredentialsStore.shared
        kolibriId = store.kolibriId
        kolibriAuthToken = store.authToken
        kolibriSaveGameKey = store.saveGameKey
    }
    
    private func saveKolibriCredentials() {
        errorMessage = nil
        successMessage = nil

        // Try to extract a UUID from pasted debug ID strings
        let candidate = kolibriId.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedID = KolibriDebugIDParser.extractLastUUID(from: candidate) ?? candidate

        do {
            try KolibriKeyStore.shared.saveKolibriID(resolvedID)
            try KolibriKeyStore.shared.saveAuthToken(kolibriAuthToken.trimmingCharacters(in: .whitespacesAndNewlines))
            try KolibriKeyStore.shared.saveSaveGameKey(kolibriSaveGameKey.trimmingCharacters(in: .whitespacesAndNewlines))

            // Refresh local state
            loadKolibriCredentials()
            successMessage = "Kolibri credentials saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearKolibriCredentials() {
        KolibriKeyStore.shared.clearAllCredentials()
        loadKolibriCredentials()
        successMessage = "Kolibri credentials cleared."
    }
}

#Preview("Settings") {
    MineOpsSettingsView()
        .preferredColorScheme(.dark)
}
