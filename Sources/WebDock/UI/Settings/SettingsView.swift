import AppKit
import SwiftUI

struct SettingsView: View {
    let environment: AppEnvironment

    @ObservedObject private var browserCatalog: BrowserCatalog
    @AppStorage(SyncPreferences.providerKey) private var providerRaw = SyncProviderKind.off.rawValue
    @AppStorage(SyncPreferences.syncedFolderPathKey) private var syncedFolderPath = ""
    @AppStorage(SyncPreferences.webDAVBaseURLKey) private var webDAVBaseURL = ""
    @AppStorage(SyncPreferences.webDAVUsernameKey) private var webDAVUsername = ""

    @StateObject private var syncStatus = SyncStatusCenter.shared
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
                        Label(page.rawValue, systemImage: page.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(9)
                            .background(selectedPage == page ? Color.accentColor.opacity(0.16) : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.padding(12).frame(width: 190)
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                    Text(selectedPage.rawValue).font(.title2.weight(.semibold))
                    Form { pageContent }.formStyle(.grouped)
                    if let statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle").foregroundStyle(.secondary)
                    }
                }.padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 780, height: 600)
        .onAppear {
            if SyncProviderKind(rawValue: providerRaw) == nil {
                providerRaw = SyncProviderKind.off.rawValue
            }
            loadWebDAVPassword()
        }
        .onChange(of: providerRaw) { _ in
            NotificationCenter.default.post(name: .webDockSyncPreferenceChanged, object: nil)
        }
        .confirmationDialog(
            "Restore WebDock Backup",
            isPresented: $showRestoreOptions,
            titleVisibility: .visible
        ) {
            Button("Replace Current Library") {
                restorePendingBackup(mode: .replace)
            }
            Button("Merge with Current Library") {
                restorePendingBackup(mode: .merge)
            }
            Button("Cancel", role: .cancel) {
                pendingRestoreURL = nil
            }
        } message: {
            Text("WebDock creates a local pre-restore snapshot first. Replace also clears device bindings for portable backups; Merge keeps current device bindings and uses newest-record-wins semantics.")
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

    @ViewBuilder private var pageContent: some View {
        switch selectedPage {
        case .general:
            Section("Launcher") {
                Toggle("Show Launcher sidebar", isOn: $sidebarVisible)
                Text("Click the Dock icon to open or hide Launcher. Use ⌘1 for Launcher and ⌘2 for Library.")
                    .foregroundStyle(.secondary)
            }
        case .browsers:
            Section("Browsers & Accounts") {
                if profileBrowsers.isEmpty {
                    Text("No supported Chromium-family browsers are currently installed.")
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
                            Button("Authorize / Rescan") {
                                _ = browserCatalog.requestProfileAccess(for: browser)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button("Request Access to Installed Browsers") {
                        browserCatalog.requestAccessForInstalledProfileBrowsers()
                    }
                    Button("Open Privacy & Security") {
                        browserCatalog.openPrivacySettings()
                    }
                }

                Text("macOS owns the Files & Folders permission. WebDock can trigger the access request but cannot enable the system switch for you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Device Resolution") {
                Text("Chromium accounts are matched between Macs by signed-in account email, never by local Profile numbers.")
                Text("If an account is missing, WebDock opens the preferred browser with its default profile and shows a warning. If the browser is missing, WebDock falls back to the system default browser.")
                    .foregroundStyle(.secondary)
            }
        case .sync:
            Section("Sync") {
                Picker("Provider", selection: $providerRaw) {
                    Text("Off").tag(SyncProviderKind.off.rawValue)
                    Text("Synced Folder").tag(SyncProviderKind.syncedFolder.rawValue)
                    Text("WebDAV").tag(SyncProviderKind.webDAV.rawValue)
                }

                if provider == .syncedFolder {
                    HStack {
                        Text(syncedFolderPath.isEmpty ? "No folder selected" : syncedFolderPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Choose Folder…") {
                            chooseSyncedFolder()
                        }
                    }
                    Text("Choose a folder managed by iCloud Drive, Dropbox, OneDrive, Syncthing, a NAS, or any other file-sync system. WebDock writes WebDockSync.json there.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if provider == .webDAV {
                    TextField("WebDAV folder URL", text: $webDAVBaseURL)
                    TextField("Username", text: $webDAVUsername)
                    SecureField("Password / app password", text: $webDAVPassword)
                    HStack {
                        Button("Save Credentials") {
                            saveWebDAVCredentials()
                        }
                        Text("The password is stored only in macOS Keychain.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("The WebDAV folder must already exist. WebDock uses ETag/If-Match conflict protection and stores only the portable canonical snapshot.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Sync Now") {
                        NotificationCenter.default.post(name: .webDockSyncRequested, object: nil)
                    }
                    .disabled(provider == .off)

                    Text(syncStatus.state.summary)
                        .foregroundStyle(.secondary)
                }
            }
        case .backup:
            Section("Backup & Restore") {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Back Up Now") {
                        createManualBackup()
                    }
                    Button("Export Portable Backup…") {
                        exportBackup()
                    }
                    Button("Restore from Backup…") {
                        chooseBackupToRestore()
                    }
                    Button("Open Backup Folder") {
                        environment.backupService.openBackupFolder()
                    }
                }

                Text("WebDock automatically creates at most one local snapshot per day and keeps the newest 20 automatic snapshots. A pre-restore snapshot is created before every restore.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Portable .webdockbackup exports include URLs, browser families, account emails, groups, ordering, and tombstones, but never local Profile numbers or device-only overrides.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .appearance:
            AppearanceSettingsView()
        case .privacy:
            Section("Privacy") {
                Text("WebDock reads only browser profile metadata needed to match account names and emails. It does not read cookies, passwords, browsing history, or saved browser credentials.")
                    .foregroundStyle(.secondary)
                Text("WebDAV passwords live in macOS Keychain. WebDock uses no Apple cloud service entitlement.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chooseSyncedFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose WebDock Sync Folder"
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
            statusMessage = "WebDAV credentials saved to Keychain."
            NotificationCenter.default.post(name: .webDockSyncPreferenceChanged, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadWebDAVPassword() {
        do {
            webDAVPassword = try WebDAVCredentialStore.password(username: webDAVUsername) ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createManualBackup() {
        do {
            let url = try environment.backupService.createManualSnapshot()
            statusMessage = "Backup created: \(url.lastPathComponent)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.title = "Export WebDock Backup"
        panel.nameFieldStringValue = "WebDock Backup.webdockbackup"
        panel.allowedFileTypes = ["webdockbackup"]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try environment.backupService.exportPortable(to: url)
            statusMessage = "Portable backup exported."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func chooseBackupToRestore() {
        let panel = NSOpenPanel()
        panel.title = "Restore WebDock Backup"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["webdockbackup"]
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
                ? "Backup restored and current library replaced."
                : "Backup merged into the current library."
        } catch {
            errorMessage = error.localizedDescription
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
