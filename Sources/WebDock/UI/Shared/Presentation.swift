import SwiftUI

struct WebDockCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06)))
    }
}

extension WebShortcut {
    var accountDisplayUsername: String? {
        guard let email = targetAccountEmail, !email.isEmpty else { return nil }
        return email.components(separatedBy: "@").first
    }

    var displaySubtitle: String {
        accountDisplayUsername ?? URL(string: normalizedURLString)?.host ?? normalizedURLString
    }
}

/// One account control; a manually entered email remains available for another Mac's account.
struct AccountSelectionView: View {
    @Binding var email: String
    let accounts: [BrowserAccountOption]
    let onRequestAccess: () -> Void
    @State private var enteringEmail = false
    @State private var draft = ""

    var body: some View {
        HStack {
            Text("Account")
            Spacer()
            Menu(email.isEmpty ? "Browser Default" : email) {
                Button("Browser Default") { email = "" }
                ForEach(accounts) { account in
                    Button(account.displayLabel) { email = account.email }
                }
                Divider()
                Button("Enter Account Email…") { draft = email; enteringEmail = true }
                Button("Authorize / Rescan") { onRequestAccess() }
            }
            .lineLimit(1)
        }
        .sheet(isPresented: $enteringEmail) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Account Email").font(.headline)
                Text("Use an account on this Mac or another Mac. Each device matches it separately.")
                    .foregroundStyle(.secondary)
                TextField("name@example.com", text: $draft)
                HStack {
                    Spacer()
                    Button("Cancel") { enteringEmail = false }.keyboardShortcut(.cancelAction)
                    Button("Use Account") { email = draft; enteringEmail = false }.keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 400)
        }
    }
}
