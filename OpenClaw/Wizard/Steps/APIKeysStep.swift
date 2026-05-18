import AppKit
import SwiftUI

struct APIKeysStep: View {
    @ObservedObject var coordinator: WizardCoordinator
    @State private var selectedProviderID = "codex"
    @State private var enabledProviderIDs: Set<String> = ["codex"]
    @State private var selectedMethodIDs: [String: String] = [:]
    @State private var credentialValues: [String: String] = [:]
    @State private var saveError: String?

    private var selectedProvider: AuthProviderDefinition {
        AuthProviderCatalog.provider(id: selectedProviderID) ?? AuthProviderCatalog.providers[0]
    }

    private var selectedMethod: AuthMethodDefinition {
        selectedProvider.method(id: selectedMethodIDs[selectedProvider.id] ?? selectedProvider.defaultMethodID)
    }

    private var isValid: Bool {
        guard !enabledProviderIDs.isEmpty else { return false }
        for provider in AuthProviderCatalog.providers where enabledProviderIDs.contains(provider.id) {
            let method = provider.method(id: selectedMethodIDs[provider.id] ?? provider.defaultMethodID)
            for field in method.fields where field.isRequired {
                if credentialValue(provider: provider, field: field).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return false
                }
            }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Authorization"))
                    .font(.system(size: 28, weight: .semibold))
                Text(L("Choose a provider first, then choose Google, official website, API key, token, or login/password where supported."))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LF("%d authorization options", AuthProviderCatalog.providers.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 14) {
                providerList
                    .frame(width: 220)
                Divider()
                providerDetail
            }
            .frame(maxHeight: .infinity)

            if let saveError {
                Label(saveError, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            } else if !isValid {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            } else {
                Label(L("Credentials are stored in macOS Keychain."), systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            WizardFooter(
                canGoBack: true,
                canContinue: isValid,
                continueTitle: L("Continue"),
                onBack: coordinator.back,
                onContinue: saveAndContinue
            )
        }
        .padding(24)
        .onAppear(perform: loadStoredCredentials)
    }

    private var providerList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(AuthProviderCatalog.providers) { provider in
                    Button {
                        selectedProviderID = provider.id
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: enabledProviderIDs.contains(provider.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(enabledProviderIDs.contains(provider.id) ? .green : .secondary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(.subheadline.weight(provider.id == selectedProviderID ? .semibold : .regular))
                                    .lineLimit(1)
                                Text(L(provider.categoryKey))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 8)
                        .background(provider.id == selectedProviderID ? Color.accentColor.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(provider.displayName)
                }
            }
        }
    }

    private var providerDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LF("Configure %@", selectedProvider.displayName))
                        .font(.headline)
                    Text(L(selectedProvider.descriptionKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: enabledBinding(for: selectedProvider))
                    .labelsHidden()
                    .accessibilityLabel(L("Enable this method"))
            }

            Toggle(L("Enable this method"), isOn: enabledBinding(for: selectedProvider))

            if enabledProviderIDs.contains(selectedProvider.id) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("Authentication method"))
                        .font(.caption.weight(.semibold))
                    Picker(L("Authentication method"), selection: methodBinding(for: selectedProvider)) {
                        ForEach(selectedProvider.methods) { method in
                            Text(L(method.titleKey)).tag(method.id)
                        }
                    }
                    .pickerStyle(.menu)
                    Text(L(selectedMethod.descriptionKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let actionTitleKey = selectedMethod.actionTitleKey, let actionURL = selectedMethod.actionURL {
                    Button {
                        NSWorkspace.shared.open(actionURL)
                    } label: {
                        Label(L(actionTitleKey), systemImage: "safari")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(selectedMethod.fields) { field in
                        credentialField(provider: selectedProvider, field: field)
                    }
                }
                if selectedMethod.fields.isEmpty {
                    Label(L("No local secret is required for this method."), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(L("Enable this method"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func credentialField(provider: AuthProviderDefinition, field: AuthFieldDefinition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(L(field.kind.titleKey))
                    .font(.caption.weight(.semibold))
                Text(field.isRequired ? L("Required") : L("Optional"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if field.kind.isSecure {
                SecureField(L(field.kind.titleKey), text: credentialBinding(provider: provider, field: field))
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(L(field.kind.titleKey), text: credentialBinding(provider: provider, field: field))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var validationMessage: String {
        enabledProviderIDs.isEmpty ? L("At least one authorization method is required.") : L("Fill required fields for enabled providers.")
    }

    private func credentialKey(provider: AuthProviderDefinition, field: AuthFieldDefinition) -> String {
        "\(provider.id).\(field.id)"
    }

    private func credentialValue(provider: AuthProviderDefinition, field: AuthFieldDefinition) -> String {
        credentialValues[credentialKey(provider: provider, field: field)] ?? ""
    }

    private func credentialBinding(provider: AuthProviderDefinition, field: AuthFieldDefinition) -> Binding<String> {
        let key = credentialKey(provider: provider, field: field)
        return Binding(
            get: { credentialValues[key] ?? "" },
            set: { credentialValues[key] = $0 }
        )
    }

    private func enabledBinding(for provider: AuthProviderDefinition) -> Binding<Bool> {
        Binding(
            get: { enabledProviderIDs.contains(provider.id) },
            set: { isEnabled in
                if isEnabled {
                    enabledProviderIDs.insert(provider.id)
                    selectedProviderID = provider.id
                } else {
                    enabledProviderIDs.remove(provider.id)
                }
            }
        )
    }

    private func loadStoredCredentials() {
        let storedIDs = AppSettings.enabledAuthProviderIDs
        enabledProviderIDs = Set(storedIDs.isEmpty ? ["codex"] : storedIDs)
        selectedProviderID = AppSettings.primaryAuthProviderID
        selectedMethodIDs = AuthProviderCatalog.providers.reduce(into: [:]) { result, provider in
            result[provider.id] = AppSettings.authMethodID(for: provider.id)
        }
        let store = KeychainStore()
        for provider in AuthProviderCatalog.providers {
            for method in provider.methods {
                for field in method.fields {
                    if let value = try? store.get(provider.keychainKey(for: field)) {
                        credentialValues[credentialKey(provider: provider, field: field)] = value
                    }
                }
            }
        }
    }

    private func saveAndContinue() {
        saveError = nil
        do {
            let enabled = AuthProviderCatalog.providers
                .map(\.id)
                .filter { enabledProviderIDs.contains($0) }
            UserDefaults.standard.set(enabled, forKey: AppSettingKeys.enabledAuthProviders)
            let primaryProviderID = enabled.contains(selectedProviderID) ? selectedProviderID : (enabled.first ?? "codex")
            UserDefaults.standard.set(primaryProviderID, forKey: AppSettingKeys.primaryAuthProvider)
            for provider in AuthProviderCatalog.providers {
                UserDefaults.standard.set(
                    selectedMethodIDs[provider.id] ?? provider.defaultMethodID,
                    forKey: AppSettingKeys.authProviderMethodPrefix + provider.id
                )
            }

            let store = KeychainStore()
            for key in AuthProviderCatalog.allKeychainKeys {
                try? store.remove(key)
            }
            for provider in AuthProviderCatalog.providers where enabledProviderIDs.contains(provider.id) {
                let method = provider.method(id: selectedMethodIDs[provider.id] ?? provider.defaultMethodID)
                for field in method.fields {
                    let value = credentialValue(provider: provider, field: field).trimmingCharacters(in: .whitespacesAndNewlines)
                    try store.set(value, for: provider.keychainKey(for: field))
                }
            }
            coordinator.next()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func methodBinding(for provider: AuthProviderDefinition) -> Binding<String> {
        Binding(
            get: { selectedMethodIDs[provider.id] ?? provider.defaultMethodID },
            set: { selectedMethodIDs[provider.id] = $0 }
        )
    }
}
