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
    @ObservedObject private var language = AppLanguage.shared
    @AppStorage("WebDock.theme") private var theme = "system"
    @AppStorage("WebDock.gridDensity") private var density = GridDensity.standard.rawValue
    @AppStorage("WebDock.subtitleMode") private var subtitle = "account"
    @AppStorage("WebDock.showBrowserBadge") private var browserBadge = true
    @AppStorage("WebDock.showWarningBadge") private var warningBadge = true
    @AppStorage("WebDock.launcherSidebarVisible") private var sidebar = true
    var body: some View {
        Section(L10n.tr("Theme")) {
            Picker(L10n.tr("Appearance"), selection: $theme) {
                Text(L10n.tr("System")).tag("system")
                Text(L10n.tr("Light")).tag("light")
                Text(L10n.tr("Dark")).tag("dark")
            }
        }
        Section(L10n.tr("Shortcuts")) {
            Picker(L10n.tr("Grid Density"), selection: $density) {
                ForEach(GridDensity.allCases) { Text(L10n.tr($0.rawValue)).tag($0.rawValue) }
            }
            Picker(L10n.tr("Subtitle"), selection: $subtitle) {
                Text(L10n.tr("Account Username")).tag("account")
                Text(L10n.tr("Domain")).tag("domain")
                Text(L10n.tr("Hidden")).tag("hidden")
            }
            Toggle(L10n.tr("Show browser badge"), isOn: $browserBadge)
            Toggle(L10n.tr("Show warning badge"), isOn: $warningBadge)
            Toggle(L10n.tr("Show sidebar"), isOn: $sidebar)
        }
    }
}

struct WebDockAppearance: ViewModifier {
    @ObservedObject private var language = AppLanguage.shared
    @AppStorage("WebDock.theme") private var theme = "system"
    func body(content: Content) -> some View {
        content.environment(\.locale, L10n.locale).preferredColorScheme(theme == "light" ? .light : theme == "dark" ? .dark : nil)
    }
}
