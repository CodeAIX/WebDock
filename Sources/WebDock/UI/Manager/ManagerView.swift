import AppKit
import SwiftUI

struct ManagerView: View {
    @ObservedObject private var language = AppLanguage.shared
    let environment: AppEnvironment

    @ObservedObject private var navigation: LibraryNavigation
    @ObservedObject private var dataStore: WebDockDataStore
    @State private var selectedID: UUID?
    @State private var editorHasChanges = false
    @State private var pendingSelection: UUID?
    @State private var showDiscardChanges = false
    @State private var showNewShortcutSheet = false
    @State private var searchText = ""
    @State private var groupFilter: UUID?

    init(environment: AppEnvironment) {
        self.environment = environment
        _navigation = ObservedObject(wrappedValue: environment.libraryNavigation)
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
        return dataStore.activeShortcuts.first(where: { $0.id == selectedID })
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    TextField(L10n.tr("Search library"), text: $searchText)
                    Button { showNewShortcutSheet = true } label: { Image(systemName: "plus") }
                        .keyboardShortcut("n").help(L10n.tr("New Shortcut"))
                }.padding(.horizontal, 12).padding(.top, 12)
                Picker(L10n.tr("Group"), selection: $groupFilter) {
                    Text(L10n.tr("All Shortcuts")).tag(nil as UUID?)
                    ForEach(dataStore.activeGroups) { Text($0.name).tag(Optional($0.id)) }
                }.padding(.horizontal, 12)
            List(selection: Binding(get: { selectedID }, set: requestSelection)) {
                ForEach(shortcuts, id: \.id) { shortcut in
                    ManagerShortcutRow(
                        shortcut: shortcut,
                        resolution: environment.deviceBindingResolver.resolution(for: shortcut),
                        iconService: environment.iconService
                    )
                    .tag(shortcut.id)
                    .contextMenu {
                        Button(L10n.tr("Move Up")) { reorder(shortcut, offset: -1) }
                        Button(L10n.tr("Move Down")) { reorder(shortcut, offset: 1) }
                    }
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
                        editorHasChanges = false
                        selectedID = shortcuts.first?.id
                    },
                    onDirtyChange: { editorHasChanges = $0 }
                )
                .id(shortcut.id)
            } else {
                WebDockEmptyStateView(
                    title: L10n.tr("Select a Shortcut"),
                    systemImage: "globe",
                    message: L10n.tr("Choose a website launch rule to edit its browser and account settings.")
                )
            }
            }
        }
        .sheet(isPresented: $showNewShortcutSheet) {
            NewShortcutSheet(environment: environment) { shortcut in
                requestSelection(shortcut.id)
            }
        }
        .onAppear {
            if selectedID == nil {
                selectedID = navigation.shortcutID ?? shortcuts.first?.id
            }
        }
        .onChange(of: navigation.shortcutID) { id in
            searchText = ""; groupFilter = nil
            requestSelection(id)
        }
        .confirmationDialog(L10n.tr("Discard unsaved changes?"), isPresented: $showDiscardChanges, titleVisibility: .visible) {
            Button(L10n.tr("Discard Changes"), role: .destructive) {
                editorHasChanges = false; selectedID = pendingSelection; pendingSelection = nil
            }
            Button(L10n.tr("Keep Editing"), role: .cancel) { pendingSelection = nil }
        }
        .onChange(of: dataStore.activeShortcuts.map(\.id)) { ids in
            if let selectedID, ids.contains(selectedID) { return }
            selectedID = ids.first
        }
    }
    private func requestSelection(_ id: UUID?) {
        guard id != selectedID else { return }
        if editorHasChanges { pendingSelection = id; showDiscardChanges = true }
        else { selectedID = id }
    }

    private func reorder(_ shortcut: WebShortcut, offset: Int) {
        guard searchText.isEmpty, groupFilter == nil,
              let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }),
              shortcuts.indices.contains(index + offset) else { return }
        do { try environment.shortcutStore.moveForDrop(shortcutID: shortcut.id, onto: shortcuts[index + offset].id) }
        catch { NSAlert(error: error).runModal() }
    }

}

private struct ManagerShortcutRow: View {
    @ObservedObject private var language = AppLanguage.shared
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
    @ObservedObject private var language = AppLanguage.shared
    private static let defaultBrowserToken = "__WEBDOCK_DEFAULT_BROWSER__"
    private static let automaticLocalBrowserToken = "__WEBDOCK_AUTOMATIC_LOCAL_BROWSER__"
    private static let defaultLocalProfileToken = "__WEBDOCK_LOCAL_BROWSER_DEFAULT__"

    let shortcut: WebShortcut
    let environment: AppEnvironment
    let onDeleted: () -> Void
    let onDirtyChange: (Bool) -> Void

    @State private var metadataBaseline: WebShortcut
    @State private var externalEdit = false
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
        onDeleted: @escaping () -> Void,
        onDirtyChange: @escaping (Bool) -> Void
    ) {
        self.shortcut = shortcut
        self.environment = environment
        self.onDeleted = onDeleted
        self.onDirtyChange = onDirtyChange
        _metadataBaseline = State(initialValue: shortcut)
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
            WebDockCard(title: L10n.tr("Shortcut")) {
                HStack(spacing: 16) {
                    WebsiteIconView(shortcut: currentShortcut, resolution: resolution, service: environment.iconService)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentShortcut.iconMode == "custom" ? L10n.tr("Custom Icon") : L10n.tr("Automatic Icon")).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button(L10n.tr("Choose Icon…")) {
                                do { try environment.iconService.chooseIcon(for: currentShortcut) }
                                catch { errorMessage = L10n.errorDescription(error) }
                            }
                            Button(L10n.tr("Reset")) {
                                do { try environment.iconService.reset(currentShortcut) }
                                catch { errorMessage = L10n.errorDescription(error) }
                            }
                            Button(L10n.tr("Refresh")) { Task { await environment.iconService.loadIfNeeded(currentShortcut, force: true) } }
                                .disabled(currentShortcut.iconMode == "custom")
                        }
                    }
                }.padding(.bottom, 6)
                TextField(L10n.tr("Name"), text: $name)
                TextField(L10n.tr("URL"), text: $urlString)
                Picker(L10n.tr("Group"), selection: $groupID) {
                    Text(L10n.tr("None")).tag(nil as UUID?)
                    ForEach(environment.dataStore.activeGroups) { Text($0.name).tag(Optional($0.id)) }
                }
                Button(L10n.tr("New Group…")) { showNewGroup = true }
            }

            WebDockCard(title: L10n.tr("Launch Rule")) {
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
                    Text(L10n.tr("Account mapping is resolved separately on each Mac."))
                        .font(.caption).foregroundStyle(.secondary)

                }
            }

            WebDockCard(title: L10n.tr("This Mac")) {
                LabeledContent(L10n.tr("Current Resolution")) {
                    Text(resolution.summary)
                        .foregroundStyle(.secondary)
                }

                if let warning = resolution.warningMessage {
                    Label(L10n.message(warning), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                } else if resolution.usesLocalOverride {
                    Label(L10n.tr("A device-only override is active. It does not sync to other Macs."), systemImage: "desktopcomputer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker(L10n.tr("Browser Override"), selection: Binding(
                    get: { localBrowserSelection },
                    set: { localBrowserSelection = $0; localProfileSelection = Self.defaultLocalProfileToken }
                )) {
                    Text(L10n.tr("Automatic from synced rule"))
                        .tag(Self.automaticLocalBrowserToken)
                    ForEach(installedBrowsers) { browser in
                        Text(browser.displayName)
                            .tag(browser.bundleIdentifier)
                    }
                }

                if let selectedLocalBrowser, selectedLocalBrowser.supportsProfiles {
                    Picker(L10n.tr("Profile Override"), selection: $localProfileSelection) {
                        Text(L10n.tr("Browser Default / Last Used"))
                            .tag(Self.defaultLocalProfileToken)
                        ForEach(localProfiles) { profile in
                            Text(profile.displayLabel)
                                .tag(profile.profileDirectory)
                        }
                    }
                }

                HStack {
                    Button(L10n.tr("Save Local Override")) {
                        applyLocalOverride()
                    }.disabled(!localOverrideChanged)
                    if hasLocalOverride {
                        Button(L10n.tr("Clear Local Override")) {
                            clearLocalOverride()
                        }
                    }
                }
            }

            WebDockCard(title: L10n.tr("Actions")) {
                if externalEdit {
                    Text(L10n.tr("This shortcut changed while you were editing. Save uses your edits, or reload the saved values."))
                        .font(.caption).foregroundStyle(.secondary)
                    Button(L10n.tr("Reload Saved Values")) { loadMetadata(currentShortcut); onDirtyChange(localOverrideChanged) }
                }
                HStack {
                    Button(L10n.tr("Test Launch")) { testLaunch() }
                    Button(L10n.tr("Duplicate")) { duplicate() }
                }
                HStack {
                    Button(L10n.tr("Save Changes")) {
                        save()
                    }
                    .keyboardShortcut("s", modifiers: [.command])

                    if didSave {
                        Label(L10n.tr("Saved"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }

                    Spacer()

                    Button(L10n.tr("Delete Shortcut"), role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
          }.padding(20)
        }
        .textFieldStyle(.roundedBorder)
        .navigationTitle(shortcut.displayName)
        .onAppear(perform: loadLocalOverride)
        .onChange(of: [name, urlString, browserSelection, accountEmail, groupID?.uuidString ?? "", localBrowserSelection, localProfileSelection]) { _ in
            onDirtyChange(hasChanges || localOverrideChanged)
        }
        .onChange(of: currentShortcut) { updated in
            if !hasChanges { loadMetadata(updated) }
            else if metadataMatches(updated, metadataBaseline) { metadataBaseline = updated }
            else { externalEdit = true }
            onDirtyChange(hasChanges || localOverrideChanged)
        }
        .onChange(of: browserSelection) { _ in
            if selectedFamily?.supportsAccountRouting != true {
                accountEmail = ""
            }
        }
        .alert(L10n.tr("New Group"), isPresented: $showNewGroup) {
            TextField(L10n.tr("Group name"), text: $newGroupName)
            Button(L10n.tr("Create")) {
                do { groupID = try environment.shortcutStore.createGroup(name: newGroupName).id; newGroupName = "" }
                catch { errorMessage = L10n.errorDescription(error) }
            }
            Button(L10n.tr("Cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            L10n.tr("Delete “%@”?", shortcut.displayName),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("Delete"), role: .destructive) {
                deleteShortcut()
            }
            Button(L10n.tr("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("This shortcut will be removed from your library and synchronized devices."))
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

    private var hasChanges: Bool {
        name != metadataBaseline.displayName || urlString != metadataBaseline.normalizedURLString ||
        browserSelection != (metadataBaseline.preferredBrowserFamily?.rawValue ?? Self.defaultBrowserToken) ||
        accountEmail != (metadataBaseline.targetAccountEmail ?? "") || groupID != metadataBaseline.groupID
    }

    private func metadataMatches(_ lhs: WebShortcut, _ rhs: WebShortcut) -> Bool {
        lhs.displayName == rhs.displayName && lhs.normalizedURLString == rhs.normalizedURLString &&
        lhs.preferredBrowserFamily == rhs.preferredBrowserFamily && lhs.targetAccountEmail == rhs.targetAccountEmail && lhs.groupID == rhs.groupID
    }

    private func loadMetadata(_ updated: WebShortcut) {
        metadataBaseline = updated
        name = updated.displayName; urlString = updated.normalizedURLString
        browserSelection = updated.preferredBrowserFamily?.rawValue ?? Self.defaultBrowserToken
        accountEmail = updated.targetAccountEmail ?? ""; groupID = updated.groupID
        externalEdit = false
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
        } catch { errorMessage = L10n.errorDescription(error) }
    }

    private func duplicate() {
        do { _ = try environment.shortcutStore.duplicate(shortcut) }
        catch { errorMessage = L10n.errorDescription(error) }
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
            loadMetadata(updated)
            resolutionRefresh = UUID()
            didSave = true
            onDirtyChange(localOverrideChanged)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                didSave = false
            }
        } catch {
            errorMessage = L10n.errorDescription(error)
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
            onDirtyChange(hasChanges)
        } catch {
            errorMessage = L10n.errorDescription(error)
        }
    }

    private func clearLocalOverride() {
        do {
            try environment.deviceBindingResolver.clearLocalOverride(for: shortcut)
            localBrowserSelection = Self.automaticLocalBrowserToken
            localProfileSelection = Self.defaultLocalProfileToken
            resolutionRefresh = UUID()
            onDirtyChange(hasChanges)
        } catch {
            errorMessage = L10n.errorDescription(error)
        }
    }

    private func deleteShortcut() {
        do {
            try environment.shortcutStore.delete(shortcut)
            onDeleted()
        } catch {
            errorMessage = L10n.errorDescription(error)
        }
    }
}
