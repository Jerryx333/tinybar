import AppKit

// Real menu/popover targets for manual overflow validation; never shipped in app.
final class MenuFixture: NSObject, NSApplicationDelegate {
    var items: [NSStatusItem] = []
    var popover: NSPopover?
    func applicationDidFinishLaunching(_ notification: Notification) {
        for index in 0..<3 {
            let item = NSStatusBar.system.statusItem(withLength: 30)
            item.button?.title = "F\(index)"
            item.button?.setAccessibilityLabel("Fixture \(index)")
            item.button?.setAccessibilityIdentifier("tinybar.fixture.\(index)")
            if index == 0 {
                let menu = NSMenu()
                menu.addItem(withTitle: "原始菜单已打开", action: nil, keyEquivalent: "")
                menu.addItem(withTitle: "退出测试应用", action: #selector(quit), keyEquivalent: "").target = self
                item.menu = menu
            } else {
                item.button?.target = self
                item.button?.tag = index
                item.button?.action = #selector(show(_:))
            }
            items.append(item)
        }
    }
    @objc func show(_ sender: NSStatusBarButton) {
        if sender.tag == 1 {
            let p = NSPopover()
            let controller = NSViewController()
            controller.view = NSTextField(labelWithString: "原始浮层已打开")
            controller.view.frame = NSRect(x: 0, y: 0, width: 200, height: 80)
            p.contentViewController = controller
            p.behavior = .transient
            popover = p
            p.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        } else {
            let menu = NSMenu()
            menu.addItem(withTitle: "按钮动作菜单已打开", action: nil, keyEquivalent: "")
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: sender)
        }
    }
    @objc func quit() { NSApp.terminate(nil) }
}
@main enum FixtureMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = MenuFixture()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}
