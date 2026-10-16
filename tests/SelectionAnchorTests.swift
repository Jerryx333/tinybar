import AppKit
@main enum SelectionAnchorTests {
    static func main() {
        let left = NSRect(x: -1920, y: -100, width: 1920, height: 1080)
        let anchor = SelectionAnchor(rect: NSRect(x: -1600, y: 900, width: 48, height: 28), visibleFrame: left)
        precondition(anchor.menuPoint == NSPoint(x: -1600, y: 896))
        let edge = SelectionAnchor(rect: NSRect(x: -2000, y: -150, width: 48, height: 28), visibleFrame: left)
        precondition(left.contains(edge.menuPoint))
        let upper = NSRect(x: 200, y: 1200, width: 1920, height: 1080)
        let other = SelectionAnchor(rect: NSRect(x: 300, y: 2200, width: 48, height: 28), visibleFrame: upper)
        precondition(other.menuPoint == NSPoint(x: 300, y: 2196))
        print("Selection anchors preserve display origins and clamp to the selected screen")
    }
}
