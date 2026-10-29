import SwiftUI

struct BrowserAccessOnboardingView: View {
    @ObservedObject var browserCatalog: BrowserCatalog
    @Environment(\.dismiss) private var dismiss
    @AppStorage("WebDock.browserAccessOnboardingShown") private var onboardingShown = false

    private var browsers: [BrowserOption] {
        browserCatalog.installedProfileBrowsers()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Browser Account Access")
                .font(.title2.weight(.semibold))

            Text("WebDock reads only browser profile metadata so it can show your account names and match an account email to the correct local browser profile. It does not read browsing history, cookies, passwords, or saved credentials.")
                .foregroundStyle(.secondary)

            if browsers.isEmpty {
                Text("No supported Chromium-family browsers are currently installed.")
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
                            Button("Authorize") {
                                _ = browserCatalog.requestProfileAccess(for: browser)
                            }
                        }
                    }
                }
            }

            Text("macOS controls the actual Files & Folders permission. WebDock can request access, but only you can approve or change the switch in System Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Open Privacy & Security") {
                    browserCatalog.openPrivacySettings()
                }
                Spacer()
                Button("Skip for Now") {
                    onboardingShown = true
                    dismiss()
                }
                Button("Request Access to Installed Browsers") {
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
