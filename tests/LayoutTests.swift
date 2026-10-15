import AppKit

@main enum LayoutTests {
    static func main() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let control = NSRect(x: 1700, y: 1056, width: 40, height: 24)
        let divider = NSRect(x: 1670, y: 1056, width: 30, height: 24)
        precondition(BarLayout.ordered(control: control, divider: divider))
        precondition(!BarLayout.ordered(control: divider, divider: control), "Reversed anchors must fail before hiding")
        precondition(!BarLayout.ordered(control: control, divider: divider.offsetBy(dx: 0, dy: -1080)))
        precondition(BarLayout.controlScreen(control, screens: [screen]) == 0)
        precondition(BarLayout.controlScreen(control.offsetBy(dx: -2000, dy: 0), screens: [screen]) == nil)
        precondition(BarLayout.controlScreen(control.offsetBy(dx: 0, dy: 100), screens: [screen]) == nil)
        precondition(BarLayout.hidingWidth(screens: []) == nil)
        precondition(BarLayout.hidingWidth(screens: [NSRect(x: 0, y: 0, width: 6000, height: 2000)]) == nil)
        let left = screen.offsetBy(dx: -1920, dy: 0)
        precondition(BarLayout.hidingWidth(screens: [screen, left]) == 4352)
        precondition(!BarLayout.displaced(divider: divider.offsetBy(dx: -1920, dy: 0), screens: [screen, left]), "Hidden items must not spill onto a screen on the left")
        precondition(BarLayout.displaced(divider: NSRect(x: -2500, y: 1056, width: 4170, height: 24), screens: [screen, left]))
        print("Layout safety checks passed")
    }
}
