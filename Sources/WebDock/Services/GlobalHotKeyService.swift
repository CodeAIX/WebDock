import AppKit
import Carbon
import Combine

struct LauncherHotKey: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let modifierMask = UInt32(controlKey | optionKey | shiftKey | cmdKey)
    static let defaultValue = LauncherHotKey(keyCode: UInt32(kVK_ANSI_W), modifiers: UInt32(controlKey | optionKey))

    var isValid: Bool {
        keyCode < 128 && ![UInt32(54), 55, 56, 57, 58, 59, 60, 61, 62, 63, UInt32(kVK_Escape)].contains(keyCode)
            && modifiers & ~Self.modifierMask == 0
            && modifiers & UInt32(controlKey | optionKey | cmdKey) != 0
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        var mask: UInt32 = 0
        if event.modifierFlags.contains(.control) { mask |= UInt32(controlKey) }
        if event.modifierFlags.contains(.option) { mask |= UInt32(optionKey) }
        if event.modifierFlags.contains(.shift) { mask |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.command) { mask |= UInt32(cmdKey) }
        modifiers = mask
    }

    var displayValue: String {
        let symbols: [(Int, String)] = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
        return symbols.filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + keyLabel
    }

    private var keyLabel: String {
        let special: [UInt32: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 76: "⌤", 114: "Help",
            115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        if let label = special[keyCode] { return label }
        let functionKeys: [UInt32] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
        if let index = functionKeys.firstIndex(of: keyCode) { return "F\(index + 1)" }
        let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
        guard let rawData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "#\(keyCode)" }
        let data = unsafeBitCast(rawData, to: CFData.self)
        let layout = unsafeBitCast(CFDataGetBytePtr(data), to: UnsafePointer<UCKeyboardLayout>.self)
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)
        let result = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState,
            characters.count, &length, &characters)
        guard result == noErr, length > 0 else { return "#\(keyCode)" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}

enum GlobalHotKeyError: Error, Equatable {
    case invalidCombination
    case unavailable
    case registrationFailed(OSStatus)

    var message: String {
        switch self {
        case .invalidCombination:
            return L10n.tr("Include Control, Option, or Command with a key. Escape cancels recording.")
        case .unavailable:
            return L10n.tr("This shortcut is in use by macOS or another application. Choose a different combination.")
        case .registrationFailed(let status):
            return L10n.tr("The global shortcut could not be registered (error %d). Try another combination.", status)
        }
    }
}

@MainActor
protocol GlobalHotKeyRegistering: AnyObject {
    /// Replaces the registration only after the new combination succeeds.
    func register(_ hotKey: LauncherHotKey, action: @escaping () -> Void) throws
    func unregister()
}

private final class HotKeyCallback {
    let id: UInt32
    var action: (() -> Void)?
    init(id: UInt32) { self.id = id }
}

@MainActor
final class CarbonHotKeyRegistrar: GlobalHotKeyRegistering {
    private static var nextID: UInt32 = 0
    private static let signature: OSType = 0x5744484B // WDHK
    private let callback: HotKeyCallback
    private var handler: EventHandlerRef?
    private var registration: EventHotKeyRef?
    private var current: LauncherHotKey?

    init() {
        Self.nextID &+= 1
        callback = HotKeyCallback(id: Self.nextID)
    }

    func register(_ hotKey: LauncherHotKey, action: @escaping () -> Void) throws {
        guard hotKey.isValid else { throw GlobalHotKeyError.invalidCombination }
        if current == hotKey { callback.action = action; return }
        guard !Self.isSystemShortcut(hotKey) else { throw GlobalHotKeyError.unavailable }
        if handler == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                let callback = Unmanaged<HotKeyCallback>.fromOpaque(context).takeUnretainedValue()
                var identifier = EventHotKeyID()
                let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                guard result == noErr, identifier.signature == 0x5744484B, identifier.id == callback.id else {
                    return OSStatus(eventNotHandledErr)
                }
                // Carbon dispatches on the application event loop; defer activation until the event returns.
                let action = callback.action
                DispatchQueue.main.async { action?() }
                return noErr
            }, 1, &eventType, Unmanaged.passUnretained(callback).toOpaque(), &handler)
            guard status == noErr else { throw GlobalHotKeyError.registrationFailed(status) }
        }
        var candidate: EventHotKeyRef?
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers,
            EventHotKeyID(signature: Self.signature, id: callback.id), GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive), &candidate)
        guard status == noErr else {
            if status == eventHotKeyExistsErr { throw GlobalHotKeyError.unavailable }
            throw GlobalHotKeyError.registrationFailed(status)
        }
        if let registration { UnregisterEventHotKey(registration) }
        registration = candidate
        current = hotKey
        callback.action = action
    }

    func unregister() {
        callback.action = nil
        if let registration { UnregisterEventHotKey(registration) }
        registration = nil
        current = nil
    }

    deinit {
        if let registration { UnregisterEventHotKey(registration) }
        if let handler { RemoveEventHandler(handler) }
    }

    private static func isSystemShortcut(_ hotKey: LauncherHotKey) -> Bool {
        var array: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&array) == noErr, let entries = array?.takeRetainedValue() as? [[String: Any]] else { return false }
        return entries.contains { entry in
            (entry[kHISymbolicHotKeyEnabled] as? NSNumber)?.boolValue == true &&
            (entry[kHISymbolicHotKeyCode] as? NSNumber)?.uint32Value == hotKey.keyCode &&
            ((entry[kHISymbolicHotKeyModifiers] as? NSNumber)?.uint32Value ?? 0) & LauncherHotKey.modifierMask == hotKey.modifiers
        }
    }
}

/// Preferences stay in this Mac's defaults, outside canonical records and sync payloads.
@MainActor
final class GlobalHotKeyService: ObservableObject {
    static let shortcutKey = "WebDock.launcherHotKey"
    static let enabledKey = "WebDock.launcherHotKeyEnabled"
    @Published private(set) var hotKey: LauncherHotKey
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isRecording = false
    @Published private(set) var isRegistered = false
    @Published private(set) var error: GlobalHotKeyError?
    private let defaults: UserDefaults
    private let registrar: GlobalHotKeyRegistering
    private var onInvoke: (() -> Void)?
    private var generation = 0

    init(defaults: UserDefaults = .standard, registrar: GlobalHotKeyRegistering? = nil, enabledByDefault: Bool = true) {
        self.defaults = defaults
        self.registrar = registrar ?? CarbonHotKeyRegistrar()
        if let data = defaults.data(forKey: Self.shortcutKey),
           let saved = try? JSONDecoder().decode(LauncherHotKey.self, from: data), saved.isValid {
            hotKey = saved
        } else {
            hotKey = .defaultValue
        }
        isEnabled = defaults.object(forKey: Self.enabledKey) == nil ? enabledByDefault : defaults.bool(forKey: Self.enabledKey)
    }

    func start(onInvoke: @escaping () -> Void) {
        self.onInvoke = onInvoke
        if isEnabled { registerCurrent() }
    }

    func stop() {
        generation &+= 1
        registrar.unregister()
        isRegistered = false
        isRecording = false
        onInvoke = nil
    }

    func setEnabled(_ enabled: Bool) {
        guard !isRecording else { return }
        error = nil
        if enabled {
            do {
                try register(hotKey)
            } catch { self.error = hotKeyError(error); return }
        } else {
            generation &+= 1
            registrar.unregister()
            isRegistered = false
        }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
    }

    func beginRecording() {
        guard !isRecording else { return }
        error = nil
        isRecording = true
        generation &+= 1
        registrar.unregister()
        isRegistered = false
    }

    func cancelRecording() {
        guard isRecording else { return }
        isRecording = false
        error = nil
        if isEnabled { registerCurrent() }
    }

    func save(_ candidate: LauncherHotKey) {
        guard candidate.isValid else { error = .invalidCombination; return }
        let wasRecording = isRecording
        do {
            if isEnabled { try register(candidate) }
            hotKey = candidate
            defaults.set(try JSONEncoder().encode(candidate), forKey: Self.shortcutKey)
            isRecording = false
            error = nil
        } catch {
            isRecording = false
            let candidateError = hotKeyError(error)
            if wasRecording && isEnabled { registerCurrent() }
            // A failed rollback is more actionable than the rejected candidate.
            if isRegistered || !isEnabled { self.error = candidateError }
            else if self.error == nil { self.error = candidateError }
        }
    }

    func retry() { error = nil; if isEnabled && !isRecording { registerCurrent() } }

    private func registerCurrent() {
        do { try register(hotKey) }
        catch { self.error = hotKeyError(error) }
    }

    private func register(_ hotKey: LauncherHotKey) throws {
        let nextGeneration = generation &+ 1
        try registrar.register(hotKey) { [weak self] in
            guard let self, self.generation == nextGeneration,
                  self.isEnabled, !self.isRecording, self.isRegistered else { return }
            self.onInvoke?()
        }
        generation = nextGeneration
        isRegistered = true
    }

    private func hotKeyError(_ error: Error) -> GlobalHotKeyError {
        error as? GlobalHotKeyError ?? .registrationFailed(OSStatus(paramErr))
    }
}
