import SwiftData
import SwiftUI

struct ManagerView: View {
    let environment: AppEnvironment

    @Query(sort: \WebShortcut.sortIndex) private var shortcuts: [WebShortcut]
    @State private var selectedID: UUID?
    @State private var showNewShortcutSheet = false

    private var selectedShortcut: WebShortcut? {
        guard let selectedID else { return nil }
        return shortcuts.first(where: { $0.id == selectedID })
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(shortcuts, id: \.id) { shortcut in
                    ManagerShortcutRow(shortcut: shortcut)
                        .tag(shortcut.id)
                }
            }
            .navigationTitle("Shortcuts")
            .frame(minWidth: 230)
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
                    description: Text("Choose a website shortcut to edit its settings.")
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
            if let selectedID, ids.contains(selectedID) {
                return
            }
            selectedID = ids.first
        }
    }
}

private struct ManagerShortcutRow: View {
    let shortcut: WebShortcut

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 34, height: 34)
                Image(systemName: shortcut.sourceType == .chromeWebloc ? "globe.badge.chevron.backward" : "globe")
                    .font(.system(size: 16, weight: .medium))
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
    private static let defaultProfileToken = "__WEBDOCK_DEFAULT_PROFILE__"

    let shortcut: WebShortcut
    let environment: AppEnvironment
    let onDeleted: () -> Void

    @State private var name: String
    @State private var urlString: String
    @State private var browserSelection: String
    @State private var browserProfileSelection: String
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var didSave = false

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
            initialValue: shortcut.browserBundleIdentifier ?? Self.defaultBrowserToken
        )
        _browserProfileSelection = State(
            initialValue: shortcut.browserProfileDirectory ?? Self.defaultProfileToken
        )
    }

    private var isOriginalBrowserShortcut: Bool {
        shortcut.launchMode == .originalShortcutFile
    }

    private var browserOptions: [BrowserOption] {
        var options = environment.browserCatalog.installedBrowsers()
        if let currentID = shortcut.browserBundleIdentifier,
           !options.contains(where: { $0.bundleIdentifier == currentID }) {
            options.append(
                BrowserOption(
                    bundleIdentifier: currentID,
                    displayName: shortcut.browserDisplayName ?? "Unavailable Browser"
                )
            )
        }
        return options
    }

    private var selectedBrowser: BrowserOption? {
        browserOptions.first(where: { $0.bundleIdentifier == browserSelection })
    }

    private var profileOptions: [BrowserProfileOption] {
        guard let selectedBrowser, selectedBrowser.supportsProfiles else { return [] }
        var options = environment.browserCatalog.profiles(for: selectedBrowser)

        if browserSelection == shortcut.browserBundleIdentifier,
           let storedDirectory = shortcut.browserProfileDirectory,
           !options.contains(where: { $0.profileDirectory == storedDirectory }) {
            options.append(
                BrowserProfileOption(
                    browserBundleIdentifier: selectedBrowser.bundleIdentifier,
                    browserDisplayName: selectedBrowser.displayName,
                    profileDirectory: storedDirectory,
                    localProfileName: shortcut.browserProfileDisplayName,
                    accountDisplayName: shortcut.browserProfileDisplayName,
                    accountEmail: shortcut.browserProfileAccountEmail,
                    routingSupport: selectedBrowser.profileRoutingSupport
                )
            )
        }
        return options
    }

    private var selectedProfile: BrowserProfileOption? {
        profileOptions.first(where: { $0.profileDirectory == browserProfileSelection })
    }

    var body: some View {
        Form {
            Section("Shortcut") {
                TextField("Name", text: $name)

                if isOriginalBrowserShortcut {
                    LabeledContent("URL") {
                        Text(shortcut.normalizedURLString)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } else {
                    TextField("URL", text: $urlString)
                }
            }

            Section("Open With") {
                if isOriginalBrowserShortcut {
                    LabeledContent("Mode") {
                        Text("Legacy original browser shortcut")
                    }
                    if let profile = shortcut.browserProfileHint, !profile.isEmpty {
                        LabeledContent("Profile / Account") {
                            Text(
                                environment.browserCatalog.displayLabelForImportedChromeProfile(profile)
                                    ?? profile
                            )
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        }
                    }
                    Text("This is a legacy source-preserving item. New imports are normalized into editable URL/browser/profile rules.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Browser", selection: $browserSelection) {
                        Text("Default Browser")
                            .tag(Self.defaultBrowserToken)
                        ForEach(browserOptions) { browser in
                            Text(browser.displayName)
                                .tag(browser.bundleIdentifier)
                        }
                    }

                    if let selectedBrowser, selectedBrowser.supportsProfiles {
                        Picker("Profile / Account", selection: $browserProfileSelection) {
                            Text("Browser Default / Last Used")
                                .tag(Self.defaultProfileToken)
                            ForEach(profileOptions) { profile in
                                Text(profile.displayLabel)
                                    .tag(profile.profileDirectory)
                            }
                        }

                        if profileOptions.isEmpty {
                            Text("No local profiles were found for this browser. WebDock reads only the browser's local profile metadata.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if selectedBrowser.profileRoutingSupport == .experimentalChromiumWebloc {
                            Text("Account names are read locally. Profile-specific launching for this Chromium-based browser is experimental; Google Chrome and Chromium are the verified paths.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Account/profile names are read locally from the browser's profile metadata. Cookies and passwords are not accessed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Storage") {
                if let managedURL = environment.shortcutStore.managedSourceURL(for: shortcut) {
                    LabeledContent("Legacy Source") {
                        Text(managedURL.lastPathComponent)
                            .foregroundStyle(.secondary)
                    }
                    Button("Reveal in Finder") {
                        perform {
                            try environment.shortcutStore.revealManagedSource(shortcut)
                        }
                    }
                } else {
                    Text("This shortcut is stored as an editable WebDock launch rule; no source shortcut file is required.")
                        .foregroundStyle(.secondary)
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
        .onChange(of: browserSelection) { oldValue, newValue in
            guard oldValue != newValue else { return }
            if newValue != shortcut.browserBundleIdentifier {
                browserProfileSelection = Self.defaultProfileToken
            }
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
            Text("Managed legacy files will be moved to the macOS Trash, not permanently erased.")
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
            let selectedBrowser = browserOptions.first(where: {
                $0.bundleIdentifier == browserSelection
            })
            let profile = browserProfileSelection == Self.defaultProfileToken
                ? nil
                : selectedProfile

            try environment.shortcutStore.updateMetadata(
                shortcut,
                name: name,
                normalizedURL: isOriginalBrowserShortcut ? shortcut.normalizedURLString : urlString,
                browserBundleIdentifier: isOriginalBrowserShortcut || browserSelection == Self.defaultBrowserToken
                    ? nil
                    : browserSelection,
                browserDisplayName: selectedBrowser?.displayName,
                browserProfileDirectory: profile?.profileDirectory,
                browserProfileDisplayName: profile?.accountDisplayName ?? profile?.localProfileName,
                browserProfileAccountEmail: profile?.accountEmail
            )
            name = shortcut.displayName
            urlString = shortcut.normalizedURLString
            browserProfileSelection = shortcut.browserProfileDirectory ?? Self.defaultProfileToken
            didSave = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                didSave = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteShortcut() {
        do {
            try environment.shortcutStore.delete(shortcut)
            onDeleted()
        } catch let storeError as ShortcutStoreError {
            errorMessage = storeError.localizedDescription
            if case .trashCleanupPending = storeError {
                onDeleted()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
