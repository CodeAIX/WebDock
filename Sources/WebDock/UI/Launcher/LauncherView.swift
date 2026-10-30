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
    @ObservedObject private var language = AppLanguage.shared
    let shortcut: WebShortcut
    let resolution: ShortcutResolution
    let iconService: ShortcutIconService
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("WebDock.gridDensity") private var densityRaw = GridDensity.standard.rawValue
    @AppStorage("WebDock.subtitleMode") private var subtitleMode = "account"
    @AppStorage("WebDock.showBrowserBadge") private var showBrowserBadge = true
    @AppStorage("WebDock.showWarningBadge") private var showWarningBadge = true
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
          VStack(spacing: 8) {
            WebsiteIconView(shortcut: shortcut, resolution: resolution, service: iconService,
                            size: (GridDensity(rawValue: densityRaw) ?? .standard).iconSize,
                            showBrowser: showBrowserBadge, showWarning: showWarningBadge)
            Text(shortcut.displayName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
            if subtitleMode != "hidden" {
                Text(subtitleMode == "domain" ? URL(string: shortcut.normalizedURLString)?.host ?? "" : shortcut.displaySubtitle)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            isHovered ? Color.primary.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .contentShape(Rectangle())
          }
        .buttonStyle(.plain)
        .scaleEffect(isHovered && !reduceMotion ? 1.025 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHovered)
        .onHover { isHovered = $0 }
        .help(resolution.warningMessage.map(L10n.message) ?? shortcut.normalizedURLString)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.tr("%@, %@, account %@", shortcut.displayName, resolution.summary, shortcut.accountDisplayUsername ?? L10n.tr("default")))
        .accessibilityHint(resolution.warningMessage.map(L10n.message) ?? L10n.tr("Open website"))
        .accessibilityAddTraits(.isButton)
    }
}

private let shortcutDragType = UTType.text

private final class LauncherDragState: ObservableObject {
    var sourceID: UUID?
    var token: String?
    var generation = 0
    var requestSequence = 0
    var lastTargetID: UUID?
}

private struct ShortcutReorderDropDelegate: DropDelegate {
    let targetID: UUID
    let canReorder: Bool
    let dragState: LauncherDragState
    let performMove: (UUID, UUID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        canReorder && info.hasItemsConforming(to: [shortcutDragType])
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info), let sourceID = dragState.sourceID,
              let token = dragState.token, sourceID != targetID, dragState.lastTargetID != targetID,
              let provider = info.itemProviders(for: [shortcutDragType]).first,
              provider.canLoadObject(ofClass: NSString.self) else { return }
        dragState.lastTargetID = targetID
        dragState.requestSequence += 1
        let sequence = dragState.requestSequence
        let generation = dragState.generation
        provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let text = value as? String else { return }
            DispatchQueue.main.async {
                guard text == token, dragState.generation == generation,
                      dragState.requestSequence == sequence else { return }
                performMove(sourceID, targetID)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        dropEntered(info: info)
        return DropProposal(operation: validateDrop(info: info) ? .copy : .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard validateDrop(info: info) else { return false }
        dragState.sourceID = nil
        dragState.token = nil
        dragState.lastTargetID = nil
        return true
    }
}

struct LauncherView: View {
    @ObservedObject private var language = AppLanguage.shared
    let environment: AppEnvironment
    let onOpenManager: () -> Void
    let onPrepareSettings: () -> Void

    @ObservedObject private var dataStore: WebDockDataStore
    @AppStorage("WebDock.browserAccessOnboardingShown") private var onboardingShown = false
    @AppStorage("WebDock.launcherSidebarVisible") private var sidebarVisible = true
    @State private var selectedGroupID: UUID?
    @AppStorage("WebDock.gridDensity") private var densityRaw = GridDensity.standard.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedShortcutID: UUID?
    @State private var pendingDelete: WebShortcut?
    @FocusState private var searchFocused: Bool
    @State private var searchText = ""
    @State private var errorMessage: String?
    @StateObject private var dragState = LauncherDragState()
    @ObservedObject private var newShortcut: NewShortcutPresentation
    @State private var showBrowserAccessOnboarding = false

    init(environment: AppEnvironment, newShortcut: NewShortcutPresentation, onOpenManager: @escaping () -> Void, onPrepareSettings: @escaping () -> Void) {
        self.environment = environment
        self.newShortcut = newShortcut
        self.onOpenManager = onOpenManager
        self.onPrepareSettings = onPrepareSettings
        _dataStore = ObservedObject(wrappedValue: environment.dataStore)
    }

    private var shortcuts: [WebShortcut] {
        dataStore.activeShortcuts
    }

    private var filtered: [WebShortcut] {
        let scoped = shortcuts.filter { selectedGroupID == nil || $0.groupID == selectedGroupID }
        guard !searchText.isEmpty else { return scoped }
        return scoped.filter { shortcut in
            shortcut.displayName.localizedCaseInsensitiveContains(searchText)
            || shortcut.normalizedURLString.localizedCaseInsensitiveContains(searchText)
            || (shortcut.targetAccountEmail?.localizedCaseInsensitiveContains(searchText) ?? false)
            || (shortcut.preferredBrowserFamily?.displayName.localizedCaseInsensitiveContains(searchText) ?? false)
            || dataStore.activeGroups.contains { $0.id == shortcut.groupID && $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var canReorder: Bool { searchText.isEmpty && selectedGroupID == nil }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { sidebarVisible.toggle() } label: {
                Image(systemName: "sidebar.left")
            }
            .help(L10n.tr("Toggle sidebar"))
            .accessibilityLabel(L10n.tr("Toggle sidebar"))
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(L10n.tr("Search websites"), text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .accessibilityIdentifier("launcher.search")
                    .onSubmit {
                        if filtered.count == 1, let shortcut = filtered.first { launch(shortcut) }
                        else { searchFocused = false; focusedShortcutID = filtered.first?.id }
                    }
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            Button { newShortcut.isPresented = true } label: { Image(systemName: "plus") }
                .help(L10n.tr("New shortcut (⌘N)"))
                .accessibilityLabel(L10n.tr("New shortcut"))
            Button(action: onOpenManager) { Image(systemName: "bookmark") }
                .help(L10n.tr("Manage shortcuts (⌘2)"))
                .accessibilityLabel(L10n.tr("Manage shortcuts"))
            settingsButton
            Button { searchFocused = true } label: { EmptyView() }
                .keyboardShortcut("f")
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .buttonStyle(.borderless)
        .font(.system(size: 16))
        .padding(.horizontal, 20)
        .frame(height: 68)
    }

    @ViewBuilder private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            LauncherSettingsButton(onPrepareSettings: onPrepareSettings)
                .keyboardShortcut(",")
                .help(L10n.tr("Settings (⌘,)"))
                .accessibilityLabel(L10n.tr("Settings"))
        } else {
            Button {
                onPrepareSettings()
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: { Image(systemName: "gearshape") }
            .keyboardShortcut(",")
            .help(L10n.tr("Settings (⌘,)"))
            .accessibilityLabel(L10n.tr("Settings"))
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("Library")).font(.caption).foregroundStyle(.secondary).padding(8)
                sidebarRow(L10n.tr("All Shortcuts"), icon: "square.grid.2x2", groupID: nil)
                if !dataStore.activeGroups.isEmpty {
                    Text(L10n.tr("Groups")).font(.caption).foregroundStyle(.secondary).padding(8)
                    ForEach(dataStore.activeGroups) { group in
                        sidebarRow(group.name, icon: "folder", groupID: group.id)
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.025))
    }

    private func sidebarRow(_ title: String, icon: String, groupID: UUID?) -> some View {
        Button { selectedGroupID = groupID } label: {
            Label(title, systemImage: icon)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(selectedGroupID == groupID ? Color.accentColor.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedGroupID == groupID ? .isSelected : [])
    }

    var body: some View {
        ZStack {
            VisualEffectView()
            VStack(spacing: 0) {
                topBar
                Divider()
                HStack(spacing: 0) {
                    if sidebarVisible {
                        sidebar
                        Divider()
                    }
                    grid
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(20)
                }
            }
        }
        .background(LauncherReturnKey {
            guard !searchFocused, let focusedShortcutID,
                  let shortcut = filtered.first(where: { $0.id == focusedShortcutID }) else { return false }
            launch(shortcut)
            return true
        })
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: dataStore.activeGroups) { groups in
            if let selectedGroupID, !groups.contains(where: { $0.id == selectedGroupID }) {
                self.selectedGroupID = nil
            }
        }
        .sheet(isPresented: $newShortcut.isPresented) {
            NewShortcutSheet(environment: environment)
        }
        .sheet(isPresented: $showBrowserAccessOnboarding) {
            BrowserAccessOnboardingView(browserCatalog: environment.browserCatalog)
        }
        .onAppear {
            if !onboardingShown {
                showBrowserAccessOnboarding = !environment.isValidation
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            dragState.generation += 1
            dragState.sourceID = nil
            dragState.token = nil
            dragState.lastTargetID = nil
        }
        .onDeleteCommand {
            if let focusedShortcutID { pendingDelete = filtered.first { $0.id == focusedShortcutID } }
        }
        .onExitCommand { NSApp.keyWindow?.orderOut(nil) }
        .confirmationDialog(L10n.tr("Delete “%@”?", pendingDelete?.displayName ?? L10n.tr("Shortcut")), isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            Button(L10n.tr("Delete Shortcut"), role: .destructive) {
                if let shortcut = pendingDelete { perform { try environment.shortcutStore.delete(shortcut) } }
                pendingDelete = nil
            }
            Button(L10n.tr("Cancel"), role: .cancel) { pendingDelete = nil }
        }
        .alert(
            "WebDock",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(L10n.tr("OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? L10n.tr("Unknown error"))
        }
    }

    @ViewBuilder private var grid: some View {
        if filtered.isEmpty {
            WebDockEmptyStateView(
                title: L10n.tr("No Shortcuts"),
                systemImage: "globe",
                message: searchText.isEmpty && selectedGroupID == nil
                    ? L10n.tr("Click + to create your first website launch rule.")
                    : L10n.tr("No shortcuts match your search.")
            )
        } else {
            GeometryReader { geometry in
                let density = GridDensity(rawValue: densityRaw) ?? .standard
                let columnCount = max(1, Int((geometry.size.width + 12) / (density.minimumWidth + 12)))
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount), spacing: 16) {
                            ForEach(filtered, id: \.id) { shortcut in
                                ShortcutTileView(shortcut: shortcut,
                                    resolution: environment.deviceBindingResolver.resolution(for: shortcut),
                                    iconService: environment.iconService
                                ) { launch(shortcut) }
                                .id(shortcut.id)
                                .focusable()
                                .focused($focusedShortcutID, equals: shortcut.id)
                                .onMoveCommand { direction in moveFocus(from: shortcut.id, direction: direction, columns: columnCount) }
                                .contextMenu { shortcutMenu(shortcut) }
                                .onDrag {
                                    guard canReorder else { return NSItemProvider() }
                                    dragState.generation += 1
                                    dragState.requestSequence = 0
                                    dragState.sourceID = shortcut.id
                                    dragState.lastTargetID = nil
                                    let token = "WebDock:" + shortcut.id.uuidString + ":" + UUID().uuidString
                                    dragState.token = token
                                    return NSItemProvider(object: token as NSString)
                                }
                                .onDrop(of: [shortcutDragType], delegate: ShortcutReorderDropDelegate(
                                    targetID: shortcut.id, canReorder: canReorder,
                                    dragState: dragState, performMove: moveShortcut))
                            }
                        }
                        .padding(4)
                    }
                    .onChange(of: focusedShortcutID) { id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
            }
        }
    }

    private func moveFocus(from id: UUID, direction: MoveCommandDirection, columns: Int) {
        guard let index = filtered.firstIndex(where: { $0.id == id }) else { return }
        let offset: Int
        switch direction { case .left: offset = -1; case .right: offset = 1; case .up: offset = -columns; case .down: offset = columns; @unknown default: return }
        let next = min(max(0, index + offset), filtered.count - 1)
        focusedShortcutID = filtered[next].id
    }

    @ViewBuilder private func shortcutMenu(_ shortcut: WebShortcut) -> some View {
        Button(L10n.tr("Open")) { launch(shortcut) }
        Button(L10n.tr("Edit")) {
            environment.libraryNavigation.shortcutID = shortcut.id
            onOpenManager()
        }
        Button(L10n.tr("Duplicate")) { perform { _ = try environment.shortcutStore.duplicate(shortcut) } }
        Divider()
        Button(L10n.tr("Change Icon…")) { perform { try environment.iconService.chooseIcon(for: shortcut) } }
        Button(L10n.tr("Reset Icon")) { perform { try environment.iconService.reset(shortcut) } }
        Button(L10n.tr("Retry Automatic Icon")) { Task { await environment.iconService.loadIfNeeded(shortcut, force: true) } }
            .disabled(shortcut.iconMode == "custom")
        Menu(L10n.tr("Move to Group")) {
            Button(L10n.tr("None")) { perform { try environment.shortcutStore.setGroup(nil, for: shortcut) } }
            ForEach(dataStore.activeGroups) { group in
                Button(group.name) { perform { try environment.shortcutStore.setGroup(group.id, for: shortcut) } }
            }
        }
        Divider()
        Button(L10n.tr("Delete…"), role: .destructive) { pendingDelete = shortcut }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = L10n.errorDescription(error) }
    }

    private func launch(_ shortcut: WebShortcut) {
        // Launcher tiles invoke an action; they are not persistent selections.
        focusedShortcutID = nil
        searchFocused = false
        do {
            let resolution = try environment.deviceBindingResolver.refreshBinding(for: shortcut)
            try environment.shortcutLauncher.launch(
                shortcut,
                resolution: resolution,
                storageRoot: environment.runtimeStorage.rootURL
            )
        } catch {
            errorMessage = L10n.errorDescription(error)
        }
    }

    private func moveShortcut(_ sourceID: UUID, onto targetID: UUID) {
        do {
            try withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                try environment.shortcutStore.moveForDrop(shortcutID: sourceID, onto: targetID)
            }
        } catch {
            errorMessage = L10n.errorDescription(error)
        }
    }
}

@available(macOS 14.0, *)
private struct LauncherSettingsButton: View {
    @ObservedObject private var language = AppLanguage.shared
    @Environment(\.openSettings) private var openSettings
    let onPrepareSettings: () -> Void

    var body: some View {
        Button {
            onPrepareSettings()
            openSettings()
        } label: { Image(systemName: "gearshape") }
    }
}
