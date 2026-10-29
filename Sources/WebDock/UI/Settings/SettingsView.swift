import SwiftUI

struct SettingsView: View {
    @AppStorage(SyncPreferences.providerKey)
    private var providerRaw = SyncProviderKind.off.rawValue

    @StateObject private var syncStatus = SyncStatusCenter.shared

    private var provider: SyncProviderKind {
        SyncProviderKind(rawValue: providerRaw) ?? .off
    }

    var body: some View {
        Form {
            Section("Sync") {
                Picker("Provider", selection: $providerRaw) {
                    Text("Off").tag(SyncProviderKind.off.rawValue)
                    Text("iCloud").tag(SyncProviderKind.iCloud.rawValue)
                    Text("WebDAV (planned)").tag(SyncProviderKind.webDAV.rawValue)
                }

                if provider == .iCloud {
                    Text("WebDock syncs only portable shortcut intent: URL, browser family, account email, groups, and order. Local Profile numbers and device overrides never leave this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if provider == .webDAV {
                    Text("WebDAV will use the same portable snapshot schema. iCloud is the first implemented provider.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Sync Now") {
                        NotificationCenter.default.post(name: .webDockSyncRequested, object: nil)
                    }
                    .disabled(provider == .off || provider == .webDAV)

                    Text(syncStatus.state.summary)
                        .foregroundStyle(syncStatusColor)
                }
            }

            Section("Device Resolution") {
                Text("Chromium accounts are matched across devices by signed-in account email, never by local Profile numbers.")
                Text("If an account is missing, WebDock opens the preferred browser with its default profile and shows a warning on that shortcut. If the browser is missing, WebDock falls back to the system default browser.")
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("WebDock reads only browser profile metadata needed to match account names and emails. It does not read cookies, passwords, or browsing history.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onChange(of: providerRaw) { _, _ in
            NotificationCenter.default.post(name: .webDockSyncPreferenceChanged, object: nil)
        }
    }

    private var syncStatusColor: Color {
        switch syncStatus.state {
        case .failure, .unavailable:
            .secondary
        case .success:
            .secondary
        case .idle, .syncing:
            .secondary
        }
    }
}
