import SwiftUI

enum GridDensity: String, CaseIterable, Identifiable {
    case comfortable = "Comfortable", standard = "Default", compact = "Compact"
    var id: String { rawValue }
    var minimumWidth: CGFloat {
        switch self { case .comfortable: 112; case .standard: 92; case .compact: 74 }
    }
    var iconSize: CGFloat {
        switch self { case .comfortable: 68; case .standard: 60; case .compact: 46 }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("WebDock.theme") private var theme = "system"
    @AppStorage("WebDock.gridDensity") private var density = GridDensity.standard.rawValue
    @AppStorage("WebDock.subtitleMode") private var subtitle = "account"
    @AppStorage("WebDock.showBrowserBadge") private var browserBadge = true
    @AppStorage("WebDock.showWarningBadge") private var warningBadge = true
    @AppStorage("WebDock.launcherSidebarVisible") private var sidebar = true
    var body: some View {
        Section("Theme") {
            Picker("Appearance", selection: $theme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
        }
        Section("Shortcuts") {
            Picker("Grid Density", selection: $density) {
                ForEach(GridDensity.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            Picker("Subtitle", selection: $subtitle) {
                Text("Account Username").tag("account")
                Text("Domain").tag("domain")
                Text("Hidden").tag("hidden")
            }
            Toggle("Show browser badge", isOn: $browserBadge)
            Toggle("Show warning badge", isOn: $warningBadge)
            Toggle("Show sidebar", isOn: $sidebar)
        }
    }
}

struct WebDockAppearance: ViewModifier {
    @AppStorage("WebDock.theme") private var theme = "system"
    func body(content: Content) -> some View {
        content.preferredColorScheme(theme == "light" ? .light : theme == "dark" ? .dark : nil)
    }
}
