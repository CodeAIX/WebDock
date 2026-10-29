import SwiftUI

struct ManagerView: View {
    let environment: AppEnvironment

    @ObservedObject private var dataStore: WebDockDataStore
    @State private var selectedID: UUID?
    @State private var showNewShortcutSheet = false
    @State private var searchText = ""
    @State private var groupFilter: UUID?

    init(environment: AppEnvironment) {
        self.environment = environment
        _dataStore = ObservedObject(wrappedValue: environment.dataStore)
    }

    private var shortcuts: [WebShortcut] {
        dataStore.activeShortcuts.filter {
            (groupFilter == nil || $0.groupID == groupFilter) &&
            (searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText)
             || $0.normalizedURLString.localizedCaseInsensitiveContains(searchText)
             || ($0.targetAccountEmail?.localizedCaseInsensitiveContains(searchText) ?? false))
        }
    }

    private var selectedShortcut: WebShortcut? {
        guard let selectedID else { return nil }
        return shortcuts.first(where: { $0.id == selectedID })
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    TextField("Search library", text: $searchText)
                    Button { showNewShortcutSheet = true } label: { Image(systemName: "plus") }
                        .keyboardShortcut("n").help("New Shortcut")
                }.padding(.horizontal, 12).padding(.top, 12)
                Picker("Group", selection: $groupFilter) {
                    Text("All Shortcuts").tag(nil as UUID?)
                    ForEach(dataStore.activeGroups) { Text($0.name).tag(Optional($0.id)) }
                }.padding(.horizontal, 12)
            List(selection: $selectedID) {
                ForEach(shortcuts, id: \.id) { shortcut in
                    ManagerShortcutRow(
                        shortcut: shortcut,
                        resolution: environment.deviceBindingResolver.resolution(for: shortcut),
                        iconService: environment.iconService
                    )
                    .tag(shortcut.id)
                }
            }
            }
            .frame(width: 240)
            Divider()
            Group {
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
                WebDockEmptyStateView(
                    title: "Select a Shortcut",
                    systemImage: "globe",
                    message: "Choose a website launch rule to edit its browser and account settings."
                )
            }
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
        .onChange(of: shortcuts.map(\.id)) { ids in
            if let selectedID, ids.contains(selectedID) { return }
            selectedID = ids.first
        }
    }
}

private struct ManagerShortcutRow: View {
    let shortcut: WebShortcut
    let resolution: ShortcutResolution
    let iconService: ShortcutIconService

    var body: some View {
        HStack(spacing: 10) {
            WebsiteIconView(shortcut: shortcut, resolution: resolution, service: iconService, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.displayName)
                    .lineLimit(1)
                Text(shortcut.displaySubtitle)
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
    @State private var groupID: UUID?
    @State private var newGroupName = ""
    @State private var showNewGroup = false
    @State private var localBrowserSelection = Self.automaticLocalBrowserToken
    @State private var localProfileSelection = Self.defaultLocalProfileToken
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var didSave = false
    @State private var resolutionRefresh = UUID()
    @State private var accountAccessRefresh = UUID()

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
        _groupID = State(initialValue: shortcut.groupID)
    }

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
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            WebDockCard(title: "Shortcut") {
                HStack(spacing: 16) {
                    WebsiteIconView(shortcut: currentShortcut, resolution: resolution, service: environment.iconService)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentShortcut.iconMode == "custom" ? "Custom Icon" : "Automatic Icon").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Choose Icon…") {
                                do { try environment.iconService.chooseIcon(for: currentShortcut) }
                                catch { errorMessage = error.localizedDescription }
                            }
                            Button("Reset") {
                                do { try environment.iconService.reset(currentShortcut) }
                                catch { errorMessage = error.localizedDescription }
                            }
                            Button("Refresh") { Task { await environment.iconService.loadIfNeeded(currentShortcut, force: true) } }
                                .disabled(currentShortcut.iconMode == "custom")
                        }
                    }
                }.padding(.bottom, 6)
                TextField("Name", text: $name)
                TextField("URL", text: $urlString)
                Picker("Group", selection: $groupID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(environment.dataStore.activeGroups) { Text($0.name).tag(Optional($0.id)) }
                }
                Button("New Group…") { showNewGroup = true }
            }

            WebDockCard(title: "Launch Rule") {
                Picker("Browser", selection: $browserSelection) {
                    Text("System Default Browser")
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
                    Text("Account mapping is resolved separately on each Mac.")
                        .font(.caption).foregroundStyle(.secondary)

                }
            }

            WebDockCard(title: "This Mac") {
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

                Picker("Browser Override", selection: Binding(
                    get: { localBrowserSelection },
                    set: { localBrowserSelection = $0; localProfileSelection = Self.defaultLocalProfileToken }
                )) {
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
                    Button("Save Local Override") {
                        applyLocalOverride()
                    }.disabled(!localOverrideChanged)
                    if hasLocalOverride {
                        Button("Clear Local Override") {
                            clearLocalOverride()
                        }
                    }
                }
            }

            WebDockCard(title: "Actions") {
                HStack {
                    Button("Test Launch") { testLaunch() }
                    Button("Duplicate") { duplicate() }
                }
                HStack {
                    Button("Save Changes") {
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
          }.padding(20)
        }
        .textFieldStyle(.roundedBorder)
        .navigationTitle(shortcut.displayName)
        .onAppear(perform: loadLocalOverride)
        .onChange(of: browserSelection) { _ in
            if selectedFamily?.supportsAccountRouting != true {
                accountEmail = ""
            }
        }
        .alert("New Group", isPresented: $showNewGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Create") {
                do { groupID = try environment.shortcutStore.createGroup(name: newGroupName).id; newGroupName = "" }
                catch { errorMessage = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) {}
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
            Text("This shortcut will be removed from your library and synchronized devices.")
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

    private var currentShortcut: WebShortcut {
        environment.dataStore.shortcut(id: shortcut.id) ?? shortcut
    }

    private var localOverrideChanged: Bool {
        let binding = environment.deviceBindingResolver.binding(for: shortcut.id)
        let browser = binding?.overrideBrowserBundleIdentifier ?? Self.automaticLocalBrowserToken
        let profile = binding?.overrideProfileDirectory ?? Self.defaultLocalProfileToken
        return browser != localBrowserSelection || profile != localProfileSelection
    }

    private func testLaunch() {
        do {
            let current = environment.dataStore.shortcut(id: shortcut.id) ?? shortcut
            let resolved = try environment.deviceBindingResolver.refreshBinding(for: current)
            try environment.shortcutLauncher.launch(current, resolution: resolved, storageRoot: environment.runtimeStorage.rootURL)
        } catch { errorMessage = error.localizedDescription }
    }

    private func duplicate() {
        do { _ = try environment.shortcutStore.duplicate(shortcut) }
        catch { errorMessage = error.localizedDescription }
    }

    private func save() {
        do {
            let updated = try environment.shortcutStore.updateMetadata(
                shortcut,
                name: name,
                normalizedURL: urlString,
                browserFamily: selectedFamily,
                targetAccountEmail: accountEmail,
                groupID: groupID
            )
            _ = try environment.deviceBindingResolver.refreshBinding(for: updated)
            name = updated.displayName
            urlString = updated.normalizedURLString
            browserSelection = updated.preferredBrowserFamily?.rawValue ?? Self.defaultBrowserToken
            accountEmail = updated.targetAccountEmail ?? ""
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
