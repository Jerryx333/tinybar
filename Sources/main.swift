import AppKit
import ServiceManagement

final class TinyBar: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private(set) var control: NSStatusItem!
    private(set) var divider: NSStatusItem!
    private(set) var collapsed = false
    private var pendingHide = false
    private var layoutReadyAfter = 0.0
    private(set) var issue: String?
    private var check: DispatchWorkItem?
    private var generation = 0
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var menu: NSMenu?
    private var helpWindow: NSWindow?
    private var helpText: NSTextField?
    private var isTerminating = false
    private var managerPresent = false
    private let controlName = "TinyBar.Control"
    private let dividerName = "TinyBar.Divider"
    // Exact IDs only. Best effort, not an exhaustive inventory of menu-bar managers.
    static let managerIDs: Set<String> = [
        "com.jordanbaird.Ice", "com.surteesstudios.Bartender",
        "com.surteesstudios.Bartender4", "com.surteesstudios.Bartender5",
        "com.dwarvesv.minimalbar", "com.mortennn.Dozer"
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if TESTING
        if Probe.runIfRequested(self) { return }
        #endif
        let current = NSRunningApplication.current
        if NSRunningApplication.runningApplications(withBundleIdentifier: "local.tinybar.app")
            .contains(where: {
                guard !$0.isTerminated, $0.processIdentifier != current.processIdentifier else { return false }
                if let otherDate = $0.launchDate, let currentDate = current.launchDate, otherDate != currentDate {
                    return otherDate < currentDate
                }
                return $0.processIdentifier < current.processIdentifier
            }) {
            // Normal launches use LaunchServices. A duplicate direct executable must never create a second divider.
            fputs("TinyBar is already running. Reopen TinyBar.app to reveal its items.\n", stderr)
            NSApp.terminate(nil)
            return
        }
        createItems()
        watchEvents()
        managerPresent = managerConflict()
        issue = managerPresent ? conflictMessage : nil
        updateControl()
        if !UserDefaults.standard.bool(forKey: "HasShownSetup") {
            UserDefaults.standard.set(true, forKey: "HasShownSetup")
            showHelp()
        }
    }

    func createItems(reset: Bool = false) {
        let defaults = UserDefaults.standard
        for (name, position) in [(controlName, 180.0), (dividerName, 220.0)] {
            let key = "NSStatusItem Preferred Position \(name)"
            // This preference key is undocumented. Use it only to seed our own items;
            // subsequent launches leave the user's system-managed arrangement alone.
            if reset || defaults.object(forKey: key) == nil { defaults.set(position, forKey: key) }
        }
        control = NSStatusBar.system.statusItem(withLength: BarLayout.controlWidth)
        control.autosaveName = controlName
        control.behavior = []
        control.isVisible = true
        control.button?.target = self
        control.button?.action = #selector(clicked)
        control.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        control.button?.setAccessibilityLabel("TinyBar：展开或收起菜单栏图标")
        divider = NSStatusBar.system.statusItem(withLength: BarLayout.dividerWidth)
        divider.autosaveName = dividerName
        divider.behavior = []
        divider.isVisible = true
        divider.button?.title = "│"
        divider.button?.toolTip = "按住 ⌘ 拖动：左侧收起，右侧常显。请把 TinyBar 箭头留在右侧。"
        divider.button?.setAccessibilityLabel("TinyBar 分隔线：左侧为隐藏组")
        (divider.button?.cell as? NSButtonCell)?.highlightsBy = []
        updateControl()
    }

    private var conflictMessage: String { "请先退出其他菜单栏管理器，再使用 TinyBar 收起图标。" }

    func managerConflict() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            !app.isTerminated && (app.bundleIdentifier.map(Self.managerIDs.contains) ?? false)
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ action: @escaping (Notification) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main, using: action)
        observers.append((center, token))
    }

    func watchEvents() {
        observe(.default, NSApplication.didChangeScreenParametersNotification) { [weak self] _ in
            self?.reveal()
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification] {
            observe(workspace, name) { [weak self] _ in self?.reveal() }
        }
        observe(workspace, NSWorkspace.didLaunchApplicationNotification) { [weak self] n in
            guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier, Self.managerIDs.contains(id) else { return }
            self?.managerPresent = true
            self?.reveal()
        }
        observe(workspace, NSWorkspace.didTerminateApplicationNotification) { [weak self] n in
            guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier, Self.managerIDs.contains(id) else { return }
            self?.managerPresent = self?.managerConflict() ?? false
            self?.issue = self?.managerPresent == true ? self?.conflictMessage : nil
            self?.updateControl()
        }
    }

    private func cancelCheck() {
        generation += 1
        check?.cancel()
        check = nil
    }

    func reveal() {
        if collapsed { layoutReadyAfter = ProcessInfo.processInfo.systemUptime + 0.15 }
        cancelCheck()
        collapsed = false
        pendingHide = false
        divider?.length = BarLayout.dividerWidth
        issue = managerPresent ? conflictMessage : nil
        updateControl()
    }

    @discardableResult
    func hide() -> Bool {
        guard !isTerminating, !collapsed, !pendingHide else { return false }
        let remaining = layoutReadyAfter - ProcessInfo.processInfo.systemUptime
        if remaining > 0 {
            // Shrinking a status item updates its width before its origin. Let that one
            // layout transaction finish; a second click/reveal cancels this request.
            cancelCheck()
            pendingHide = true
            let expected = generation
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.generation == expected, self.pendingHide else { return }
                self.pendingHide = false
                self.check = nil
                // Deferred rejection uses the warning icon/tooltip; do not open a menu
                // after the user's click has already finished.
                _ = self.hide()
            }
            check = work
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
            updateControl()
            return true
        }
        managerPresent = managerConflict()
        if managerPresent { return reject(conflictMessage) }
        let screens = NSScreen.screens
        let frames = screens.map(\.frame)
        guard let width = BarLayout.hidingWidth(screens: frames) else {
            return reject("当前屏幕布局过宽，已保持展开。")
        }
        guard let c = control.button?.window?.frame, let d = divider.button?.window?.frame,
              control.isVisible, divider.isVisible,
              let index = BarLayout.controlScreen(c, screens: frames),
              BarLayout.controlScreen(NSRect(x: d.maxX - 1, y: d.minY, width: 1, height: d.height), screens: frames) == index else {
            // Fullscreen/auto-hidden menu-bar geometry may be transient. Fail open, without a modal alert.
            return reject("菜单栏位置暂不可用，已保持展开。可重新打开 TinyBar 找回入口。")
        }
        let notchSafe = screens[index].auxiliaryTopRightArea ?? .zero
        guard notchSafe.isEmpty || (c.minX >= notchSafe.minX && c.maxX <= notchSafe.maxX) else {
            return reject("入口靠近刘海，请按住 ⌘ 将箭头移到菜单栏右侧。")
        }
        guard BarLayout.ordered(control: c, divider: d) else {
            return reject("请按住 ⌘ 将分隔线放在 TinyBar 箭头左侧，再收起。")
        }
        cancelCheck()
        issue = nil
        collapsed = true
        divider.length = width
        updateControl()
        let expected = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == expected, self.collapsed else { return }
            self.check = nil
            let currentScreens = NSScreen.screens.map(\.frame)
            guard let control = self.control.button?.window?.frame,
                  let divider = self.divider.button?.window?.frame,
                  BarLayout.controlScreen(control, screens: currentScreens) != nil,
                  BarLayout.ordered(control: control, divider: divider),
                  BarLayout.displaced(divider: divider, screens: currentScreens) else {
                self.reveal()
                self.issue = "系统未能安全收起图标，已恢复展开。"
                self.updateControl()
                return
            }
        }
        check = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        return true
    }

    private func reject(_ message: String) -> Bool {
        reveal()
        issue = message
        updateControl()
        return false
    }

    private func updateControl() {
        guard let button = control?.button else { return }
        let hiding = collapsed || pendingHide
        let symbol = issue == nil ? (hiding ? "chevron.left" : "chevron.right") : "exclamationmark.circle"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.image?.isTemplate = true
        button.toolTip = issue ?? (hiding ? "TinyBar · 点击展开，右键设置" : "TinyBar · 点击收起，右键设置")
        button.setAccessibilityValue(pendingHide ? "正在收起" : (collapsed ? "已收起" : "已展开"))
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else if collapsed || pendingHide {
            reveal()
        } else if !hide() {
            showMenu()
        }
    }

    @objc private func revealItems() { reveal() }
    @objc private func hideItems() { if !hide() { showHelp() } }

    private func add(_ title: String, action: Selector?, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = action != nil
        menu.addItem(item)
        return item
    }

    private func showMenu() {
        guard let button = control.button else { return }
        let m = NSMenu()
        m.autoenablesItems = false
        m.delegate = self
        if let issue {
            _ = add(issue, action: nil, to: m)
            m.addItem(.separator())
        }
        let hiding = collapsed || pendingHide
        _ = add(hiding ? "展开图标" : "收起图标", action: hiding ? #selector(revealItems) : #selector(hideItems), to: m)
        _ = add("排列图标与恢复…", action: #selector(showHelp), to: m)
        m.addItem(.separator())
        let service = SMAppService.mainApp
        let login = add("登录时启动", action: #selector(toggleLogin), to: m)
        switch service.status {
        case .enabled: login.state = .on
        case .requiresApproval: login.state = .mixed; login.title = "登录时启动（等待系统允许）"
        case .notRegistered: login.state = .off
        case .notFound: login.title = "登录时启动（请先安装到 Applications）"; login.isEnabled = false
        @unknown default: login.isEnabled = false
        }
        if service.status == .requiresApproval {
            _ = add("打开系统登录项设置…", action: #selector(openLoginSettings), to: m)
        }
        m.addItem(.separator())
        _ = add("展开并退出 TinyBar", action: #selector(quit), to: m)
        self.menu = m
        m.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
    }

    func menuDidClose(_ menu: NSMenu) { self.menu = nil }

    @objc private func toggleLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval: try SMAppService.mainApp.unregister()
            case .notRegistered: try SMAppService.mainApp.register()
            case .notFound: throw NSError(domain: "TinyBar", code: 1, userInfo: [NSLocalizedDescriptionKey: "请先安装 TinyBar.app，再设置登录启动。"])
            @unknown default: throw NSError(domain: "TinyBar", code: 2, userInfo: [NSLocalizedDescriptionKey: "系统返回了未知的登录项状态。"])
            }
            if SMAppService.mainApp.status == .requiresApproval {
                issue = "请在系统设置 → 通用 → 登录项中允许 TinyBar。"
                showHelp()
            }
        } catch {
            issue = "登录项设置失败：\(error.localizedDescription)"
            showHelp()
        }
        updateControl()
    }

    @objc private func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    @objc func showHelp() {
        let message = issue
        reveal()
        if helpWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 245),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "TinyBar"
            window.isReleasedWhenClosed = false
            window.delegate = self
            let content = window.contentView!
            let title = NSTextField(labelWithString: "把不常用的图标收起来")
            title.font = .systemFont(ofSize: 17, weight: .semibold)
            title.frame = NSRect(x: 24, y: 194, width: 320, height: 24)
            content.addSubview(title)
            let text = NSTextField(wrappingLabelWithString: "")
            text.font = .systemFont(ofSize: 13)
            text.frame = NSRect(x: 24, y: 74, width: 312, height: 110)
            content.addSubview(text)
            helpText = text
            let reset = NSButton(title: "找回入口", target: self, action: #selector(resetPosition))
            reset.bezelStyle = .rounded
            reset.frame = NSRect(x: 18, y: 22, width: 100, height: 32)
            content.addSubview(reset)
            let exit = NSButton(title: "退出", target: self, action: #selector(quit))
            exit.bezelStyle = .rounded
            exit.frame = NSRect(x: 128, y: 22, width: 80, height: 32)
            content.addSubview(exit)
            let done = NSButton(title: "开始使用", target: self, action: #selector(closeHelp))
            done.bezelStyle = .rounded
            done.keyEquivalent = "\r"
            done.frame = NSRect(x: 232, y: 22, width: 106, height: 32)
            content.addSubview(done)
            helpWindow = window
        }
        let instructions = "按住 ⌘ 拖动菜单栏图标：\n分隔线 │ 左侧会收起，右侧保持显示。\n把 TinyBar 箭头留在分隔线右侧。\n\n点击箭头展开 / 收起；右键打开设置。"
        helpText?.stringValue = message.map { "\($0)\n\n先展开，再按住 ⌘ 排列图标。" } ?? instructions
        helpWindow?.center()
        helpWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closeHelp() { helpWindow?.close() }

    func windowWillClose(_ notification: Notification) {
        helpText = nil
        helpWindow = nil
    }

    @objc func resetPosition() {
        reveal()
        // Only our two anchors are recreated. Other apps' status-item preferences are untouched.
        if let control { NSStatusBar.system.removeStatusItem(control) }
        if let divider { NSStatusBar.system.removeStatusItem(divider) }
        createItems(reset: true)
        helpText?.stringValue = "已将 TinyBar 入口放回右侧。\n\n按住 ⌘ 将分隔线移到合适位置，再把不常用的图标移到它左侧。"
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHelp()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        reveal()
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        // Leave item positions to AppKit; process teardown removes both status-item windows.
    }
}

let app = NSApplication.shared
let delegate = TinyBar()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
