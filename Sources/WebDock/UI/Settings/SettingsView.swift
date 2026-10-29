import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("WebDock") {
                Text("Website shortcuts stay local on this Mac.")
                Text("WebDock opens shortcuts in external browsers and does not embed websites.")
            }

            Section("Development status") {
                Text("v0.1 — implementation in progress")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
