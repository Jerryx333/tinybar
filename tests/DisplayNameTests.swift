import AppKit

@main enum DisplayNameTests {
    static func main() {
        typealias Item = MenuBarDisplay.Item
        let cc = MenuBarDisplay.controlCenterBundleID
        // Localized app name is the same for every system item; it must not decide the title.
        func system(_ label: String, _ id: String?, own: Bool = true, ordinal: Int = 0) -> String {
            MenuBarDisplay.title(Item(appName: "控制中心", label: label, hasOwnLabel: own,
                                      identifier: id, bundleID: cc, ordinal: ordinal))
        }
        let wifi = system("Wi-Fi，已接入，3格", "com.apple.menuextra.wifi")
        let bluetooth = system("蓝牙", "com.apple.menuextra.bluetooth")
        let battery = system("电池", "com.apple.menuextra.battery")
        let sound = system("声音", "com.apple.menuextra.sound")
        precondition(wifi == "Wi-Fi，已接入，3格" && bluetooth == "蓝牙" && battery == "电池" && sound == "声音")
        precondition(Set([wifi, bluetooth, battery, sound]).count == 4, "System items must have distinct names")
        for name in [wifi, bluetooth, battery, sound] { precondition(!name.hasPrefix("控制中心 ·")) }
        precondition(system("控制中心、录屏正被使用", "com.apple.menuextra.controlcenter") == "控制中心、录屏正被使用")
        // Known identifier without its own AX label uses the identifier table.
        precondition(system("控制中心 · 3", "com.apple.menuextra.bluetooth", own: false) == "蓝牙")
        precondition(system("控制中心 · 3", "com.apple.menuextra.future", own: false) == "系统项目（future）")
        // Classification by identifier alone works under any localization or bundle.
        precondition(MenuBarDisplay.title(Item(appName: "Control Centre", label: "Battery",
                                               identifier: "com.apple.menuextra.battery")) == "Battery")
        // A localized app name equal to "控制中心" is not identity without bundle/identifier.
        precondition(!MenuBarDisplay.isSystem(Item(appName: "控制中心", label: "x", bundleID: "com.example.fake")))

        // Anonymous Control Center proxy: explicitly unknown, never another app's name.
        let anonymous = system("控制中心 · 39", nil, own: false, ordinal: 38)
        precondition(anonymous.hasPrefix("未识别") && anonymous.contains("39"), anonymous)
        precondition(!["微信", "Orca", "Bob", "蓝牙", "Wi-Fi"].contains { anonymous.contains($0) })
        precondition(system("控制中心 · 39", nil, own: false, ordinal: 38) != system("控制中心 · 40", nil, own: false, ordinal: 39))

        // Third-party: real app names, fallback "<app> · 1" label is not repeated.
        func app(_ name: String, _ bundle: String, label: String? = nil, peer: Int = 1, peers: Int = 1) -> String {
            MenuBarDisplay.title(Item(appName: name, label: label ?? "\(name) · 1", hasOwnLabel: label != nil,
                                      identifier: nil, bundleID: bundle), peer: peer, peers: peers)
        }
        let wechat = app("微信", "com.tencent.xinWeChat"), orca = app("Orca", "com.example.orca"), bob = app("Bob", "com.example.bob")
        precondition(wechat == "微信" && orca == "Orca" && bob == "Bob", "\(wechat) \(orca) \(bob)")
        // Same app, multiple items: distinguishable.
        let first = app("Orca", "com.example.orca", peer: 1, peers: 2), second = app("Orca", "com.example.orca", peer: 2, peers: 2)
        precondition(first == "Orca · 1/2" && second == "Orca · 2/2")
        precondition(app("Orca", "com.example.orca", label: "Sync", peer: 2, peers: 2) == "Orca · 2/2 · Sync")
        precondition(app("Orca", "com.example.orca", label: "Orca") == "Orca")

        // Width: measure full text, cap long text, never truncate short text.
        let font = NSFont.systemFont(ofSize: 11)
        func fits(_ text: String, screen: CGFloat = 1440) -> (CGFloat, CGFloat) {
            let measured = (text as NSString).size(withAttributes: [.font: font]).width
            return (MenuBarDisplay.hoverWidth(textWidth: measured, screenWidth: screen) - 20, measured)
        }
        for text in [bluetooth, wifi, wechat, first, anonymous, "控制中心、录屏正被使用"] {
            let (room, measured) = fits(text)
            precondition(room >= measured, "Short title must not truncate: \(text) \(room) < \(measured)")
        }
        let long = String(repeating: "很长的菜单栏项目名称", count: 20)
        precondition(MenuBarDisplay.hoverWidth(textWidth: fits(long).1, screenWidth: 1440) == 360)
        precondition(MenuBarDisplay.hoverWidth(textWidth: fits(long).1, screenWidth: 200) == 184)
        precondition(MenuBarDisplay.hoverWidth(textWidth: .infinity, screenWidth: 1440) == 360)
        precondition(MenuBarDisplay.hoverWidth(textWidth: 0, screenWidth: 1440) >= 36)
        // Different measured titles receive enough room rather than a fixed tooltip width.
        precondition(fits(bluetooth).0 > 20 && fits(wifi).0 > fits(bluetooth).0)
        print("Display names: system by identifier, third-party by app, peers, unknown proxy, measured widths passed")
    }
}
