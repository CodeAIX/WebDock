import SwiftUI

struct BrowserAccessOnboardingView: View {
    @ObservedObject private var language = AppLanguage.shared
    @ObservedObject var browserCatalog: BrowserCatalog
    @Environment(\.dismiss) private var dismiss
    @AppStorage("WebDock.browserAccessOnboardingShown") private var onboardingShown = false

    private var browsers: [BrowserOption] {
        browserCatalog.installedProfileBrowsers()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.tr("Browser Account Access"))
                .font(.title2.weight(.semibold))

            Text(L10n.tr("WebDock reads only browser profile metadata so it can show your account names and match an account email to the correct local browser profile. It does not read browsing history, cookies, passwords, or saved credentials."))
                .foregroundStyle(.secondary)

            if browsers.isEmpty {
                Text(L10n.tr("No supported Chromium-family browsers are currently installed."))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(browsers) { browser in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(browser.displayName)
                                Text(browserCatalog.accessStatus(for: browser).label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(L10n.tr("Authorize")) {
                                _ = browserCatalog.requestProfileAccess(for: browser)
                            }
                        }
                    }
                }
            }

            Text(L10n.tr("macOS controls the actual Files & Folders permission. WebDock can request access, but only you can approve or change the switch in System Settings."))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(L10n.tr("Open Privacy & Security")) {
                    browserCatalog.openPrivacySettings()
                }
                Spacer()
                Button(L10n.tr("Skip for Now")) {
                    onboardingShown = true
                    dismiss()
                }
                Button(L10n.tr("Request Access to Installed Browsers")) {
                    browserCatalog.requestAccessForInstalledProfileBrowsers()
                    onboardingShown = true
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 580)
    }
}
