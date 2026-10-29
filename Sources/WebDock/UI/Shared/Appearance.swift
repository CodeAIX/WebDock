import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("WebDock.theme") private var theme = "system"
    var body: some View {
        Section("Theme") {
            Picker("Appearance", selection: $theme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
        }
    }
}

struct WebDockAppearance: ViewModifier {
    @AppStorage("WebDock.theme") private var theme = "system"
    func body(content: Content) -> some View {
        content.preferredColorScheme(theme == "light" ? .light : theme == "dark" ? .dark : nil)
    }
}
