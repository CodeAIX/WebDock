import SwiftUI

struct NewShortcutSheet: View {
    private static let defaultBrowserToken = "__WEBDOCK_DEFAULT_BROWSER__"

    let environment: AppEnvironment
    var onCreated: ((WebShortcut) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var urlString = ""
    @State private var browserSelection = Self.defaultBrowserToken
    @State private var accountEmail = ""
    @State private var errorMessage: String?

    private var selectedFamily: BrowserFamily? {
        browserSelection == Self.defaultBrowserToken
            ? nil
            : BrowserFamily(rawValue: browserSelection)
    }

    private var localAccounts: [BrowserAccountOption] {
        guard let selectedFamily, selectedFamily.supportsAccountRouting else { return [] }
        return environment.browserCatalog.accounts(for: selectedFamily)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Shortcut")
                .font(.title2.weight(.semibold))

            Form {
                Section("Website") {
                    TextField("Name (optional)", text: $name)
                    TextField("https://example.com", text: $urlString)
                }

                Section("Open With") {
                    Picker("Browser", selection: $browserSelection) {
                        Text("System Default Browser")
                            .tag(Self.defaultBrowserToken)
                        ForEach(BrowserFamily.allCases) { family in
                            Text(family.displayName)
                                .tag(family.rawValue)
                        }
                    }

                    if let selectedFamily, selectedFamily.supportsAccountRouting {
                        TextField("Account email (optional)", text: $accountEmail)

                        Menu("Choose Local Account…") {
                            if localAccounts.isEmpty {
                                Text("No signed-in accounts found on this Mac")
                            } else {
                                ForEach(localAccounts) { account in
                                    Button(account.displayLabel) {
                                        accountEmail = account.email
                                    }
                                }
                            }
                        }

                        Text("The account email is the portable identity that syncs between Macs. Local Profile numbers are detected separately on each device and never sync.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Create") {
                    createShortcut()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 540, height: 430)
        .onChange(of: browserSelection) { _, _ in
            if selectedFamily?.supportsAccountRouting != true {
                accountEmail = ""
            }
        }
        .alert(
            "WebDock",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func createShortcut() {
        do {
            let shortcut = try environment.shortcutCreationService.create(
                name: name,
                url: urlString,
                browserFamily: selectedFamily,
                targetAccountEmail: accountEmail
            )
            _ = try environment.deviceBindingResolver.refreshBinding(for: shortcut)
            onCreated?(shortcut)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
