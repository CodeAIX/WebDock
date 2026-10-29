import SwiftData
import SwiftUI

struct ManagerView: View {
    let environment: AppEnvironment

    @Query(sort: \WebShortcut.sortIndex) private var allShortcuts: [WebShortcut]
    @State private var selectedID: UUID?
    @State private var showNewShortcutSheet = false

    private var shortcuts: [WebShortcut] {
        allShortcuts.filter { $0.deletedAt == nil }
    }

    private var selectedShortcut: WebShortcut? {
        guard let selectedID else { return nil }
        return shortcuts.first(where: { $0.id == selectedID })
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(shortcuts, id: \.id) { shortcut in
                    ManagerShortcutRow(
                        shortcut: shortcut,
                        resolution: environment.deviceBindingResolver.resolution(for: shortcut)
                    )
                    .tag(shortcut.id)
                }
            }
            .navigationTitle("Shortcuts")
            .frame(minWidth: 240)
        } detail: {
            if let shortcut = selectedShortcut {
                ShortcutEditorView(
                    shortcut: shortcut,
                    environment: environment,
                    onDeleted: {
                        selectedID = shortcuts.first?.id
                    }
                )
                .id(shortcut.id)
            } else {
                ContentUnavailableView(
                    "Select a Shortcut",
                    systemImage: "globe",
                    description: Text("Choose a website launch rule to edit its browser and account settings.")
                )
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showNewShortcutSheet = true
                } label: {
                    Label("New Shortcut", systemImage: "plus")
                }
                .help("New Shortcut")
            }
        }
        .sheet(isPresented: $showNewShortcutSheet) {
            NewShortcutSheet(environment: environment) { shortcut in
                selectedID = shortcut.id
            }
        }
        .onAppear {
            if selectedID == nil {
                selectedID = shortcuts.first?.id
            }
        }
        .onChange(of: shortcuts.map(\.id)) { _, ids in
            if let selectedID, ids.contains(selectedID) { return }
            selectedID = ids.first
        }
    }
}

private struct ManagerShortcutRow: View {
    let shortcut: WebShortcut
    let resolution: ShortcutResolution

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 34, height: 34)
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 34, height: 34)
                if resolution.hasWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                        .offset(x: 4, y: -3)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.displayName)
                    .lineLimit(1)
                Text(URL(string: shortcut.normalizedURLString)?.host ?? shortcut.normalizedURLString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct ShortcutEditorView: View {
    private static let defaultBrowserToken = "__WEBDOCK_DEFAULT_BROWSER__"
    private static let automaticLocalBrowserToken = "__WEBDOCK_AUTOMATIC_LOCAL_BROWSER__"
    private static let defaultLocalProfileToken = "__WEBDOCK_LOCAL_BROWSER_DEFAULT__"

    let shortcut: WebShortcut
    let environment: AppEnvironment
    let onDeleted: () -> Void

    @State private var name: String
    @State private var urlString: String
    @State private var browserSelection: String
    @State private var accountEmail: String
    @State private var localBrowserSelection = Self.automaticLocalBrowserToken
    @State private var localProfileSelection = Self.defaultLocalProfileToken
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var didSave = false
    @State private var resolutionRefresh = UUID()

    init(
        shortcut: WebShortcut,
        environment: AppEnvironment,
        onDeleted: @escaping () -> Void
    ) {
        self.shortcut = shortcut
        self.environment = environment
        self.onDeleted = onDeleted
        _name = State(initialValue: shortcut.displayName)
        _urlString = State(initialValue: shortcut.normalizedURLString)
        _browserSelection = State(
            initialValue: shortcut.preferredBrowserFamily?.rawValue ?? Self.defaultBrowserToken
        )
        _accountEmail = State(initialValue: shortcut.targetAccountEmail ?? "")
    }

    private var selectedFamily: BrowserFamily? {
        browserSelection == Self.defaultBrowserToken
            ? nil
            : BrowserFamily(rawValue: browserSelection)
    }

    private var localAccounts: [BrowserAccountOption] {
        guard let selectedFamily, selectedFamily.supportsAccountRouting else { return [] }
        return environment.browserCatalog.accounts(for: selectedFamily)
    }

    private var installedBrowsers: [BrowserOption] {
        environment.browserCatalog.installedBrowsers()
    }

    private var selectedLocalBrowser: BrowserOption? {
        installedBrowsers.first(where: { $0.bundleIdentifier == localBrowserSelection })
    }

    private var localProfiles: [BrowserProfileOption] {
        guard let selectedLocalBrowser else { return [] }
        return environment.browserCatalog.profiles(for: selectedLocalBrowser)
    }

    private var resolution: ShortcutResolution {
        _ = resolutionRefresh
        return environment.deviceBindingResolver.resolution(for: shortcut)
    }

    private var hasLocalOverride: Bool {
        environment.deviceBindingResolver.binding(for: shortcut.id)?.overrideBrowserBundleIdentifier != nil
    }

    var body: some View {
        Form {
            Section("Shortcut") {
                TextField("Name", text: $name)
                TextField("URL", text: $urlString)
            }

            Section("Synced Launch Rule") {
                Picker("Browser", selection: $browserSelection) {
                    Text("System Default Browser")
                        .tag(Self.defaultBrowserToken)
                    ForEach(BrowserFamily.allCases) { family in
                        Text(family.displayName)
                            .tag(family.rawValue)
                    }
                }

                if let selectedFamily, selectedFamily.supportsAccountRouting {
                    TextField("Account Email", text: $accountEmail)

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

                    Text("Only the account email syncs. WebDock resolves that account to this Mac's local Profile directory at launch time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("This Mac") {
                LabeledContent("Current Resolution") {
                    Text(resolution.summary)
                        .foregroundStyle(.secondary)
                }

                if let warning = resolution.warningMessage {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                } else if resolution.usesLocalOverride {
                    Label("A device-only override is active. It does not sync to other Macs.", systemImage: "desktopcomputer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Browser Override", selection: $localBrowserSelection) {
                    Text("Automatic from synced rule")
                        .tag(Self.automaticLocalBrowserToken)
                    ForEach(installedBrowsers) { browser in
                        Text(browser.displayName)
                            .tag(browser.bundleIdentifier)
                    }
                }

                if let selectedLocalBrowser, selectedLocalBrowser.supportsProfiles {
                    Picker("Profile Override", selection: $localProfileSelection) {
                        Text("Browser Default / Last Used")
                            .tag(Self.defaultLocalProfileToken)
                        ForEach(localProfiles) { profile in
                            Text(profile.displayLabel)
                                .tag(profile.profileDirectory)
                        }
                    }
                }

                HStack {
                    Button("Apply to This Mac") {
                        applyLocalOverride()
                    }
                    if hasLocalOverride {
                        Button("Clear Local Override") {
                            clearLocalOverride()
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button("Save") {
                        save()
                    }
                    .keyboardShortcut("s", modifiers: [.command])

                    if didSave {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }

                    Spacer()

                    Button("Delete Shortcut", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .navigationTitle(shortcut.displayName)
        .onAppear(perform: loadLocalOverride)
        .onChange(of: browserSelection) { _, _ in
            if selectedFamily?.supportsAccountRouting != true {
                accountEmail = ""
            }
        }
        .onChange(of: localBrowserSelection) { _, _ in
            localProfileSelection = Self.defaultLocalProfileToken
        }
        .confirmationDialog(
            "Delete “\(shortcut.displayName)”?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteShortcut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The deletion is synchronized so the shortcut does not reappear on another device.")
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

    private func save() {
        do {
            try environment.shortcutStore.updateMetadata(
                shortcut,
                name: name,
                normalizedURL: urlString,
                browserFamily: selectedFamily,
                targetAccountEmail: accountEmail
            )
            _ = try environment.deviceBindingResolver.refreshBinding(for: shortcut)
            name = shortcut.displayName
            urlString = shortcut.normalizedURLString
            browserSelection = shortcut.preferredBrowserFamily?.rawValue ?? Self.defaultBrowserToken
            accountEmail = shortcut.targetAccountEmail ?? ""
            resolutionRefresh = UUID()
            didSave = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                didSave = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadLocalOverride() {
        guard let binding = environment.deviceBindingResolver.binding(for: shortcut.id),
              let bundleIdentifier = binding.overrideBrowserBundleIdentifier else {
            localBrowserSelection = Self.automaticLocalBrowserToken
            localProfileSelection = Self.defaultLocalProfileToken
            return
        }
        localBrowserSelection = bundleIdentifier
        localProfileSelection = binding.overrideProfileDirectory ?? Self.defaultLocalProfileToken
    }

    private func applyLocalOverride() {
        do {
            if localBrowserSelection == Self.automaticLocalBrowserToken {
                try environment.deviceBindingResolver.clearLocalOverride(for: shortcut)
            } else {
                try environment.deviceBindingResolver.setLocalOverride(
                    for: shortcut,
                    browserBundleIdentifier: localBrowserSelection,
                    profileDirectory: localProfileSelection == Self.defaultLocalProfileToken
                        ? nil
                        : localProfileSelection
                )
            }
            resolutionRefresh = UUID()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearLocalOverride() {
        do {
            try environment.deviceBindingResolver.clearLocalOverride(for: shortcut)
            localBrowserSelection = Self.automaticLocalBrowserToken
            localProfileSelection = Self.defaultLocalProfileToken
            resolutionRefresh = UUID()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteShortcut() {
        do {
            try environment.shortcutStore.delete(shortcut)
            onDeleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
