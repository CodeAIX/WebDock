import AppKit
import SwiftData
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ShortcutTileView: View {
    let shortcut: WebShortcut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: 60, height: 60)
                    Image(systemName: "globe")
                        .font(.system(size: 28, weight: .medium))
                }
                Text(shortcut.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .help(shortcut.normalizedURLString)
        .accessibilityLabel("\(shortcut.displayName), \(URL(string: shortcut.normalizedURLString)?.host ?? shortcut.normalizedURLString)")
    }
}

struct LauncherView: View {
    let environment: AppEnvironment
    @Query(sort: \WebShortcut.sortIndex) private var shortcuts: [WebShortcut]
    @State private var searchText = ""

    private var filtered: [WebShortcut] {
        guard !searchText.isEmpty else { return shortcuts }
        return shortcuts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
            || $0.normalizedURLString.localizedCaseInsensitiveContains(searchText)
            || ($0.browserProfileHint?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        ZStack {
            VisualEffectView()
            VStack(spacing: 16) {
                HStack {
                    TextField("Search websites", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        // TODO(v0.1): route through an app coordinator to show Manager window.
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.borderless)
                }

                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Shortcuts",
                        systemImage: "globe",
                        description: Text("Drag a .crwebloc, .webloc, or .url shortcut onto WebDock.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 92, maximum: 110), spacing: 12)],
                            spacing: 16
                        ) {
                            ForEach(filtered) { shortcut in
                                ShortcutTileView(shortcut: shortcut) {
                                    try? environment.shortcutLauncher.launch(
                                        shortcut,
                                        storageRoot: environment.managedStorage.rootURL
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onExitCommand {
            NSApp.keyWindow?.orderOut(nil)
        }
    }
}
