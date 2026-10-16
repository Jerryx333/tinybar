import AppKit

struct SelectionAnchor {
    let rect: NSRect // Global AppKit coordinates, including negative display origins.
    let visibleFrame: NSRect

    var menuPoint: NSPoint {
        NSPoint(x: min(max(rect.minX, visibleFrame.minX + 4), visibleFrame.maxX - 4),
                y: min(max(rect.minY - 4, visibleFrame.minY + 4), visibleFrame.maxY - 4))
    }
}
