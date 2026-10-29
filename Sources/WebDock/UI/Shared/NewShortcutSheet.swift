import SwiftUI

struct NewShortcutSheet: View {
    @ObservedObject private var language = AppLanguage.shared
    private static let defaultBrowserToken = "__WEBDOCK_DEFAULT_BROWSER__"

    let environment: AppEnvironment
    var onCreated: ((WebShortcut) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var urlString = ""
    @State private var browserSelection = Self.defaultBrowserToken
    @State private var accountEmail = ""
    @State private var errorMessage: String?
    @State private var accountAccessRefresh = UUID()

    private var selectedFamily: BrowserFamily? {
        browserSelection == Self.defaultBrowserToken
            ? nil
            : BrowserFamily(rawValue: browserSelection)
    }

    private var localAccounts: [BrowserAccountOption] {
        _ = accountAccessRefresh
        guard let selectedFamily, selectedFamily.supportsAccountRouting else { return [] }
        return environment.browserCatalog.accounts(for: selectedFamily)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.tr("New Shortcut"))
                .font(.title2.weight(.semibold))

            Form {
                Section(L10n.tr("Website")) {
                    TextField(L10n.tr("Name (optional)"), text: $name)
                    TextField("https://example.com", text: $urlString)
                }

                Section(L10n.tr("Open With")) {
                    Picker(L10n.tr("Browser"), selection: $browserSelection) {
                        Text(L10n.tr("System Default Browser"))
                            .tag(Self.defaultBrowserToken)
                        ForEach(BrowserFamily.allCases) { family in
                            Text(family.displayName)
                                .tag(family.rawValue)
                        }
                    }

                    if let selectedFamily, selectedFamily.supportsAccountRouting {
                        AccountSelectionView(email: $accountEmail, accounts: localAccounts) {
                            environment.browserCatalog.requestProfileAccess(for: selectedFamily)
                            accountAccessRefresh = UUID()
                        }

                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(L10n.tr("Cancel"), role: .cancel) {
                    dismiss()
                }
                Button(L10n.tr("Create")) {
                    createShortcut()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 540, height: 430)
        .onChange(of: browserSelection) { _ in
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
            Button(L10n.tr("OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? L10n.tr("Unknown error"))
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
            errorMessage = L10n.errorDescription(error)
        }
    }
}
