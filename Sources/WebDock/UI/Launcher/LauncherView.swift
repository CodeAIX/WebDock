import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

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

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 60, height: 60)
                Image(systemName: shortcut.sourceType == .chromeWebloc ? "globe.badge.chevron.backward" : "globe")
                    .font(.system(size: 28, weight: .medium))
            }
            Text(shortcut.displayName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            isHovered ? Color.primary.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { isHovered = $0 }
        .help(shortcut.normalizedURLString)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shortcut.displayName), \(URL(string: shortcut.normalizedURLString)?.host ?? shortcut.normalizedURLString)")
        .accessibilityAddTraits(.isButton)
    }
}

private struct ShortcutReorderDropDelegate: DropDelegate {
    let targetID: UUID
    let canReorder: Bool
    @Binding var draggedShortcutID: UUID?
    let performMove: (UUID, UUID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        canReorder && draggedShortcutID != nil && draggedShortcutID != targetID
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else {
            return DropProposal(operation: .cancel)
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard canReorder,
              let sourceID = draggedShortcutID,
              sourceID != targetID else {
            draggedShortcutID = nil
            return false
        }

        performMove(sourceID, targetID)
        draggedShortcutID = nil
        return true
    }
}

struct LauncherView: View {
    let environment: AppEnvironment
    let onOpenManager: () -> Void

    @Query(sort: \WebShortcut.sortIndex) private var shortcuts: [WebShortcut]
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var draggedShortcutID: UUID?

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
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search websites", text: $searchText)
                        .textFieldStyle(.plain)
                    Button(action: onOpenManager) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.borderless)
                    .help("Manage shortcuts")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Shortcuts",
                        systemImage: "globe",
                        description: Text(
                            searchText.isEmpty
                                ? "Drag a .crwebloc, .webloc, or .url shortcut onto WebDock."
                                : "No shortcuts match your search."
                        )
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 92, maximum: 110), spacing: 12)],
                            spacing: 16
                        ) {
                            ForEach(filtered, id: \.id) { shortcut in
                                ShortcutTileView(shortcut: shortcut) {
                                    launch(shortcut)
                                }
                                .opacity(draggedShortcutID == shortcut.id ? 0.55 : 1)
                                .onDrag {
                                    guard searchText.isEmpty else {
                                        return NSItemProvider()
                                    }
                                    draggedShortcutID = shortcut.id
                                    return NSItemProvider(object: shortcut.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.plainText],
                                    delegate: ShortcutReorderDropDelegate(
                                        targetID: shortcut.id,
                                        canReorder: searchText.isEmpty,
                                        draggedShortcutID: $draggedShortcutID,
                                        performMove: moveShortcut
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onExitCommand {
            NSApp.keyWindow?.orderOut(nil)
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

    private func launch(_ shortcut: WebShortcut) {
        do {
            try environment.shortcutLauncher.launch(
                shortcut,
                storageRoot: environment.managedStorage.rootURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveShortcut(_ sourceID: UUID, onto targetID: UUID) {
        do {
            try environment.shortcutStore.moveForDrop(
                shortcutID: sourceID,
                onto: targetID
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
