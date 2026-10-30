import AppKit
import SwiftUI

/// Sets our Settings window title through public AppKit APIs, including runtime language changes.
struct LocalizedWindowTitle: NSViewRepresentable {
    let title: String
    func makeNSView(context: Context) -> TitleView { TitleView(title: title) }
    func updateNSView(_ view: TitleView, context: Context) {
        view.title = title
        view.window?.title = title
    }
    final class TitleView: NSView {
        var title: String
        init(title: String) { self.title = title; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.title = title }
    }
}
