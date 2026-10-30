import AppKit
import SwiftUI

struct WebsiteIconView: View {
    let shortcut: WebShortcut
    let resolution: ShortcutResolution
    @ObservedObject var service: ShortcutIconService
    var size: CGFloat = 60
    var showBrowser = true
    var showWarning = true

    private var browserURL: URL? {
        if let browser = resolution.browser {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleIdentifier)
        }
        guard let url = URL(string: shortcut.normalizedURLString) else { return nil }
        return NSWorkspace.shared.urlForApplication(toOpen: url)
    }

    private var browserName: String {
        resolution.browser?.displayName ?? browserURL?.deletingPathExtension().lastPathComponent ?? "System default browser"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
            if let image = service.image(for: shortcut) {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit().padding(size * 0.08)
            } else if service.loading.contains(shortcut.id) {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "globe").font(.system(size: size * 0.46)).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if showBrowser, let browserURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: browserURL.path))
                    .resizable().frame(width: size * 0.36, height: size * 0.36)
                    .padding(2).background(.regularMaterial, in: Circle())
                    .offset(x: 4, y: 4)
                    .accessibilityLabel("Opens with \(browserName)")
            }
        }
        .overlay(alignment: .topTrailing) {
            if showWarning, resolution.hasWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: max(10, size * 0.22)))
                    .foregroundStyle(.yellow).offset(x: 4, y: -3)
                    .help(resolution.warningMessage ?? "Launch fallback")
            }
        }
        .accessibilityLabel("Website icon, \(browserName)")
        .task(id: shortcut.normalizedURLString + (shortcut.iconAssetID ?? "")) {
            await service.loadIfNeeded(shortcut)
        }
    }
}
