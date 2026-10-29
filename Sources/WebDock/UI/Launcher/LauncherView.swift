import AppKit
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
    let resolution: ShortcutResolution
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 60, height: 60)
                Image(systemName: "globe")
                    .font(.system(size: 28, weight: .medium))
                    .frame(width: 60, height: 60)
                if resolution.hasWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.yellow)
                        .offset(x: 5, y: -4)
                }
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
        .help(resolution.warningMessage ?? shortcut.normalizedURLString)
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

    @ObservedObject private var dataStore: WebDockDataStore
    @AppStorage("WebDock.browserAccessOnboardingShown") private var onboardingShown = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var draggedShortcutID: UUID?
    @State private var showNewShortcutSheet = false
    @State private var showBrowserAccessOnboarding = false

    init(environment: AppEnvironment, onOpenManager: @escaping () -> Void) {
        self.environment = environment
        self.onOpenManager = onOpenManager
        _dataStore = ObservedObject(wrappedValue: environment.dataStore)
    }

    private var shortcuts: [WebShortcut] {
        dataStore.activeShortcuts
    }

    private var filtered: [WebShortcut] {
        guard !searchText.isEmpty else { return shortcuts }
        return shortcuts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
            || $0.normalizedURLString.localizedCaseInsensitiveContains(searchText)
            || ($0.targetAccountEmail?.localizedCaseInsensitiveContains(searchText) ?? false)
            || ($0.preferredBrowserFamily?.displayName.localizedCaseInsensitiveContains(searchText) ?? false)
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
                    Button {
                        showNewShortcutSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("New shortcut")
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
                    WebDockEmptyStateView(
                        title: "No Shortcuts",
                        systemImage: "globe",
                        message: searchText.isEmpty
                            ? "Click + to create your first website launch rule."
                            : "No shortcuts match your search."
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 92, maximum: 110), spacing: 12)],
                            spacing: 16
                        ) {
                            ForEach(filtered, id: \.id) { shortcut in
                                let resolution = environment.deviceBindingResolver.resolution(for: shortcut)
                                ShortcutTileView(
                                    shortcut: shortcut,
                                    resolution: resolution
                                ) {
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
        .sheet(isPresented: $showNewShortcutSheet) {
            NewShortcutSheet(environment: environment)
        }
        .sheet(isPresented: $showBrowserAccessOnboarding) {
            BrowserAccessOnboardingView(browserCatalog: environment.browserCatalog)
        }
        .onAppear {
            if !onboardingShown {
                showBrowserAccessOnboarding = true
            }
        }
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
            let resolution = try environment.deviceBindingResolver.refreshBinding(for: shortcut)
            try environment.shortcutLauncher.launch(
                shortcut,
                resolution: resolution,
                storageRoot: environment.runtimeStorage.rootURL
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
