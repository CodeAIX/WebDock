import SwiftUI

struct NewShortcutSheet: View {
    private static let defaultBrowserToken = "__WEBDOCK_DEFAULT_BROWSER__"
    private static let defaultProfileToken = "__WEBDOCK_DEFAULT_PROFILE__"

    let environment: AppEnvironment
    var onCreated: ((WebShortcut) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var urlString = ""
    @State private var browserSelection = Self.defaultBrowserToken
    @State private var profileSelection = Self.defaultProfileToken
    @State private var errorMessage: String?

    private var browsers: [BrowserOption] {
        environment.browserCatalog.installedBrowsers()
    }

    private var selectedBrowser: BrowserOption? {
        browsers.first(where: { $0.bundleIdentifier == browserSelection })
    }

    private var profiles: [BrowserProfileOption] {
        guard let selectedBrowser, selectedBrowser.supportsProfiles else { return [] }
        return environment.browserCatalog.profiles(for: selectedBrowser)
    }

    private var selectedProfile: BrowserProfileOption? {
        guard profileSelection != Self.defaultProfileToken else { return nil }
        return profiles.first(where: { $0.profileDirectory == profileSelection })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Shortcut")
                .font(.title2.weight(.semibold))

            Form {
                Section("Website") {
                    TextField("Name (optional)", text: $name)
                    TextField("https://example.com", text: $urlString)
                }

                Section("Open With") {
                    Picker("Browser", selection: $browserSelection) {
                        Text("Default Browser")
                            .tag(Self.defaultBrowserToken)
                        ForEach(browsers) { browser in
                            Text(browser.displayName)
                                .tag(browser.bundleIdentifier)
                        }
                    }

                    if let selectedBrowser, selectedBrowser.supportsProfiles {
                        Picker("Profile / Account", selection: $profileSelection) {
                            Text("Browser Default / Last Used")
                                .tag(Self.defaultProfileToken)
                            ForEach(profiles) { profile in
                                Text(profile.displayLabel)
                                    .tag(profile.profileDirectory)
                            }
                        }

                        if profiles.isEmpty {
                            Text("No local profiles were found for this browser.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if selectedBrowser.profileRoutingSupport == .experimentalChromiumWebloc {
                            Text("Profile-specific launching for this Chromium-based browser is experimental.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Create") {
                    createShortcut()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520, height: 390)
        .onChange(of: browserSelection) { _, _ in
            profileSelection = Self.defaultProfileToken
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

    private func createShortcut() {
        do {
            let shortcut = try environment.shortcutCreationService.create(
                name: name,
                url: urlString,
                browser: selectedBrowser,
                profile: selectedProfile
            )
            onCreated?(shortcut)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
