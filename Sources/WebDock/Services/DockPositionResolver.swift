import AppKit

struct DockPositionResolver {
    enum Edge { case bottom, left, right }

    func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            return screen
        }
        return NSApp.keyWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    func inferredDockEdge(on screen: NSScreen) -> Edge {
        let full = screen.frame
        let visible = screen.visibleFrame
        let left = max(0, visible.minX - full.minX)
        let right = max(0, full.maxX - visible.maxX)
        let bottom = max(0, visible.minY - full.minY)
        let values: [(Edge, CGFloat)] = [(.left, left), (.right, right), (.bottom, bottom)]
        guard let best = values.max(by: { $0.1 < $1.1 }), best.1 > 2 else { return .bottom }
        return best.0
    }

    func origin(for panelSize: NSSize, on screen: NSScreen, margin: CGFloat = 12) -> NSPoint {
        let visible = screen.visibleFrame
        let raw: NSPoint
        switch inferredDockEdge(on: screen) {
        case .bottom:
            raw = NSPoint(x: visible.midX - panelSize.width / 2, y: visible.minY + margin)
        case .left:
            raw = NSPoint(x: visible.minX + margin, y: visible.midY - panelSize.height / 2)
        case .right:
            raw = NSPoint(x: visible.maxX - panelSize.width - margin, y: visible.midY - panelSize.height / 2)
        }

        return NSPoint(
            x: min(max(raw.x, visible.minX + margin), visible.maxX - panelSize.width - margin),
            y: min(max(raw.y, visible.minY + margin), visible.maxY - panelSize.height - margin)
        )
    }
}
