import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var language = AppLanguage.shared
    let environment: AppEnvironment

    @ObservedObject private var browserCatalog: BrowserCatalog
    @AppStorage(SyncPreferences.providerKey) private var providerRaw = SyncProviderKind.off.rawValue
    @AppStorage(SyncPreferences.syncedFolderPathKey) private var syncedFolderPath = ""
    @AppStorage(SyncPreferences.webDAVBaseURLKey) private var webDAVBaseURL = ""
    @AppStorage(SyncPreferences.webDAVUsernameKey) private var webDAVUsername = ""

    @StateObject private var syncStatus = SyncStatusCenter.shared
    @State private var testingConnection = false
    @State private var selectedPage = SettingsPage.general
    @AppStorage("WebDock.launcherSidebarVisible") private var sidebarVisible = true
    @State private var webDAVPassword = ""
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var pendingRestoreURL: URL?
    @State private var showRestoreOptions = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _browserCatalog = ObservedObject(wrappedValue: environment.browserCatalog)
    }

    private var provider: SyncProviderKind {
        SyncProviderKind(rawValue: providerRaw) ?? .off
    }

    private var profileBrowsers: [BrowserOption] {
        browserCatalog.installedProfileBrowsers()
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(SettingsPage.allCases) { page in
                    Button { selectedPage = page; statusMessage = nil } label: {
                        Label(L10n.tr(page.rawValue), systemImage: page.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(9)
                            .contentShape(Rectangle())
                            .background(selectedPage == page ? Color.accentColor.opacity(0.16) : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.padding(12).frame(width: 190)
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                    Text(L10n.tr(selectedPage.rawValue)).font(.title2.weight(.semibold))
                    Form { pageContent }.formStyle(.grouped)
                    if let statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle").foregroundStyle(.secondary)
                    }
                }.padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 780, height: 600)
        .background(LocalizedWindowTitle(title: L10n.tr("WebDock Settings")).frame(width: 0, height: 0))
        .onAppear {
            if SyncProviderKind(rawValue: providerRaw) == nil {
                providerRaw = SyncProviderKind.off.rawValue
            }
            loadWebDAVPassword()
        }
        .onChange(of: language.preference) { _ in statusMessage = nil }
        .onChange(of: webDAVUsername) { _ in loadWebDAVPassword() }
        .onChange(of: providerRaw) { _ in
            NotificationCenter.default.post(name: .webDockSyncPreferenceChanged, object: nil)
        }
        .confirmationDialog(
            L10n.tr("Restore WebDock Backup"),
            isPresented: $showRestoreOptions,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("Replace Current Library")) {
                restorePendingBackup(mode: .replace)
            }
            Button(L10n.tr("Merge with Current Library")) {
                restorePendingBackup(mode: .merge)
            }
            Button(L10n.tr("Cancel"), role: .cancel) {
                pendingRestoreURL = nil
            }
        } message: {
            Text(L10n.tr("A safety backup is created first. Replace swaps the current library; Merge combines both libraries using the latest edits. Browser accounts are matched on this Mac."))
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

    @ViewBuilder private var pageContent: some View {
        switch selectedPage {
        case .general:
            Section(L10n.tr("Language")) { LanguageSettingsView() }
            Section(L10n.tr("Launcher")) {
                Toggle(L10n.tr("Show Launcher sidebar"), isOn: $sidebarVisible)
                Text(L10n.tr("Click the Dock icon to open or hide Launcher. Use ⌘1 for Launcher and ⌘2 for Library."))
                    .foregroundStyle(.secondary)
            }
        case .browsers:
            Section(L10n.tr("Browsers & Accounts")) {
                if profileBrowsers.isEmpty {
                    Text(L10n.tr("No supported Chromium-family browsers are currently installed."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(profileBrowsers) { browser in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(browser.displayName)
                                Text(browserCatalog.accessStatus(for: browser).label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(L10n.tr("Authorize / Rescan")) {
                                _ = browserCatalog.requestProfileAccess(for: browser)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button(L10n.tr("Request Access to Installed Browsers")) {
                        browserCatalog.requestAccessForInstalledProfileBrowsers()
                    }
                    Button(L10n.tr("Open Privacy & Security")) {
                        browserCatalog.openPrivacySettings()
                    }
                }

                Text(L10n.tr("macOS owns the Files & Folders permission. WebDock can trigger the access request but cannot enable the system switch for you."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.tr("After replacing an ad-hoc signed build, macOS may require authorization again. Quit extra copies, keep WebDock in Applications, and retry here."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(L10n.tr("Device Resolution")) {
                Text(L10n.tr("Chromium accounts are matched between Macs by signed-in account email, never by local Profile numbers."))
                Text(L10n.tr("If an account is missing, WebDock opens the preferred browser with its default profile and shows a warning. If the browser is missing, WebDock falls back to the system default browser."))
                    .foregroundStyle(.secondary)
            }
        case .sync:
            Section(L10n.tr("Sync")) {
                Picker(L10n.tr("Provider"), selection: $providerRaw) {
                    Text(L10n.tr("Off")).tag(SyncProviderKind.off.rawValue)
                    Text(L10n.tr("Synced Folder")).tag(SyncProviderKind.syncedFolder.rawValue)
                    Text("WebDAV").tag(SyncProviderKind.webDAV.rawValue)
                }

                if provider == .syncedFolder {
                    HStack {
                        Text(syncedFolderPath.isEmpty ? L10n.tr("No folder selected") : syncedFolderPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.tr("Choose Folder…")) {
                            chooseSyncedFolder()
                        }
                    }
                    Text(L10n.tr("Choose a folder managed by iCloud Drive, Dropbox, OneDrive, Syncthing, a NAS, or any other file-sync system. WebDock writes WebDockSync.json there."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if provider == .webDAV {
                    TextField(L10n.tr("WebDAV folder URL"), text: $webDAVBaseURL)
                    TextField(L10n.tr("Username"), text: $webDAVUsername)
                    SecureField(L10n.tr("Password / app password"), text: $webDAVPassword)
                    HStack {
                        Button(testingConnection ? L10n.tr("Testing…") : L10n.tr("Test Connection")) {
                            testingConnection = true
                            Task { @MainActor in
                                defer { testingConnection = false }
                                do { statusMessage = try await environment.syncCoordinator.testConnection() }
                                catch { errorMessage = L10n.errorDescription(error) }
                            }
                        }.disabled(testingConnection)
                        Button(L10n.tr("Save Credentials")) {
                            saveWebDAVCredentials()
                        }
                        Text(L10n.tr("The password is stored only in macOS Keychain."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(L10n.tr("The WebDAV folder must already exist. WebDock uses ETag/If-Match conflict protection and stores only the portable canonical snapshot."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button(L10n.tr("Sync Now")) {
                        NotificationCenter.default.post(name: .webDockSyncRequested, object: nil)
                    }
                    .disabled(provider == .off)

                    Text(syncStatus.state.summary)
                        .foregroundStyle(.secondary)
                }
            }
        case .backup:
            Section(L10n.tr("Backup & Restore")) {
                VStack(alignment: .leading, spacing: 12) {
                    Button(L10n.tr("Back Up Now")) {
                        createManualBackup()
                    }
                    Button(L10n.tr("Export Portable Backup…")) {
                        exportBackup()
                    }
                    Button(L10n.tr("Restore from Backup…")) {
                        chooseBackupToRestore()
                    }
                    Button(L10n.tr("Open Backup Folder")) {
                        environment.backupService.openBackupFolder()
                    }
                }

                Text(L10n.tr("WebDock automatically creates at most one local snapshot per day and keeps the newest 20 automatic snapshots. A pre-restore snapshot is created before every restore."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.tr("Portable .webdockbackup exports include URLs, browser families, account emails, groups, ordering, icons, and tombstones, but never local Profile numbers or device-only overrides."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .appearance:
            Section(L10n.tr("Application icon")) { AppIconSettingsView(service: environment.appIconService) }
            AppearanceSettingsView()
        case .privacy:
            Section(L10n.tr("Privacy")) {
                Text(L10n.tr("WebDock reads only browser profile metadata needed to match account names and emails. It does not read cookies, passwords, browsing history, or saved browser credentials."))
                    .foregroundStyle(.secondary)
                Text(L10n.tr("Automatic website icons request public icon metadata from each website using a separate session without browser cookies or credentials. Custom website icons and account emails are included in portable backups and your selected sync destination."))
                    .foregroundStyle(.secondary)
                Text(L10n.tr("WebDAV passwords live in macOS Keychain."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chooseSyncedFolder() {
        let panel = NSOpenPanel()
        panel.title = L10n.tr("Choose WebDock Sync Folder")
        panel.prompt = L10n.tr("Choose")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        syncedFolderPath = url.path
        providerRaw = SyncProviderKind.syncedFolder.rawValue
        NotificationCenter.default.post(name: .webDockSyncPreferenceChanged, object: nil)
    }

    private func saveWebDAVCredentials() {
        do {
            try WebDAVCredentialStore.setPassword(webDAVPassword, username: webDAVUsername)
            statusMessage = L10n.tr("WebDAV credentials saved to Keychain.")
            NotificationCenter.default.post(name: .webDockSyncPreferenceChanged, object: nil)
        } catch {
            errorMessage = L10n.errorDescription(error)
        }
    }

    private func loadWebDAVPassword() {
        do {
            webDAVPassword = try WebDAVCredentialStore.password(username: webDAVUsername) ?? ""
        } catch {
            errorMessage = L10n.errorDescription(error)
        }
    }

    private func createManualBackup() {
        do {
            let url = try environment.backupService.createManualSnapshot()
            statusMessage = L10n.tr("Backup created: %@", url.lastPathComponent)
        } catch {
            errorMessage = L10n.errorDescription(error)
        }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.title = L10n.tr("Export WebDock Backup")
        panel.prompt = L10n.tr("Save")
        panel.nameFieldStringValue = L10n.tr("WebDock Backup.webdockbackup")
        panel.allowedContentTypes = [UTType(filenameExtension: "webdockbackup") ?? .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try environment.backupService.exportPortable(to: url)
            statusMessage = L10n.tr("Portable backup exported.")
        } catch {
            errorMessage = L10n.errorDescription(error)
        }
    }

    private func chooseBackupToRestore() {
        let panel = NSOpenPanel()
        panel.title = L10n.tr("Restore WebDock Backup")
        panel.prompt = L10n.tr("Open")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "webdockbackup") ?? .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingRestoreURL = url
        showRestoreOptions = true
    }

    private func restorePendingBackup(mode: BackupRestoreMode) {
        guard let url = pendingRestoreURL else { return }
        defer { pendingRestoreURL = nil }
        do {
            try environment.backupService.restore(from: url, mode: mode)
            statusMessage = mode == .replace
                ? L10n.tr("Backup restored and current library replaced.")
                : L10n.tr("Backup merged into the current library.")
        } catch {
            errorMessage = L10n.errorDescription(error)
        }
    }
}

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General", browsers = "Browsers & Accounts", sync = "Sync"
    case backup = "Backup & Restore", appearance = "Appearance", privacy = "Privacy"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .browsers: "person.crop.circle"
        case .sync: "arrow.triangle.2.circlepath"
        case .backup: "externaldrive"
        case .appearance: "paintbrush"
        case .privacy: "hand.raised"
        }
    }
}
