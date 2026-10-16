import AppKit
import ApplicationServices

final class OverflowPanel: NSObject, NSPopoverDelegate {
    private var popover: NSPopover?
    private var request: CatalogRequest?
    private var generation = 0
    private var entries: [MenuBarEntry] = []
    private var buttons: [NSButton] = []
    private var imageTask: Task<Void, Never>?
    private let imageCache = StatusImageCache()
    private var cachedAppearance: NSAppearance.Name?
    var groupBoundary: (() -> CGRect?)?
    private var boundary: CGRect?
    private var cachedBoundary: CGRect?
    private var lastDismissal = -Double.infinity
    // Retain bounded snapshots, never views or a background timer.
    // Every selection is revalidated by MenuBarCatalog.press before acting.
    private var cached: CatalogSnapshot?
    private var cachedAt = -Double.infinity
    var isShown: Bool { popover?.isShown == true }
    var onSelect: ((MenuBarEntry, SelectionAnchor) -> Void)?
    var onClose: (() -> Void)?
    private weak var anchor: NSView?
    private var anchorRight: CGFloat = 0
    private var anchorScreen: NSScreen?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var hideWork: DispatchWorkItem?
    private var hideArmed = false
    private var hoverIndex: Int?
    private var hoverWork: DispatchWorkItem?
    private var hoverPanel: NSPanel?

    func toggle(relativeTo button: NSView) {
        // A transient popup can dismiss on mouse-down before the status button's
        // mouse-up action arrives. Do not immediately reopen that same popup.
        guard ProcessInfo.processInfo.systemUptime - lastDismissal > 0.3 else { return }
        if isShown { close() } else { show(relativeTo: button) }
    }

    func show(relativeTo button: NSView) {
        close()
        anchor = button
        boundary = groupBoundary?()
        if boundary != cachedBoundary { cached = nil }
        if let window = button.window {
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            anchorRight = rect.maxX
            anchorScreen = window.screen
        }
        let popup = NSPopover()
        popup.behavior = .transient
        popup.animates = false
        popup.appearance = button.effectiveAppearance
        let appearance = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        if appearance != cachedAppearance || !CGPreflightScreenCaptureAccess() || !MenuBarCatalog.trusted {
            imageCache.clear()
            cachedAppearance = appearance
        }
        popup.delegate = self
        let controller = NSViewController()
        controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 388, height: 160))
        popup.contentViewController = controller
        popover = popup
        let trusted = MenuBarCatalog.trusted
        let showingCache: Bool
        if trusted, let cached, !cached.entries.isEmpty, ProcessInfo.processInfo.systemUptime - cachedAt < 300 {
            showingCache = true
            entries = grouped(cached.entries)
            render(cached)
            setStripHelp("上次列表，正在更新；横向滚动查看更多")
        } else {
            showingCache = false
            cached = nil
            renderLoading()
        }
        popup.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        controller.view.window?.acceptsMouseMovedEvents = true
        alignToLeft()
        startAutoHide()
        if trusted { load(preserveDisplayedEntries: showingCache) }
        updateHover()
    }

    func close() {
        clearHover()
        hideArmed = false
        hideWork?.cancel(); hideWork = nil
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        mouseMonitor = nil; localMouseMonitor = nil
        generation += 1
        request?.cancel()
        request = nil
        entries.removeAll()
        buttons.removeAll()
        imageTask?.cancel(); imageTask = nil
        let existing = popover
        popover = nil
        existing?.close()
        existing?.contentViewController = nil
    }

    func invalidateCache() {
        close()
        cached = nil
        cachedBoundary = nil
        imageCache.clear()
    }

    private func startAutoHide() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in self?.checkPointer() }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            self?.checkPointer()
            return event
        }
        checkPointer()
    }

    private func checkPointer() {
        guard isShown else { return }
        updateHover()
        if pointerInside() {
            hideArmed = true
            hideWork?.cancel(); hideWork = nil
        } else if hideArmed && hideWork == nil {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.hideWork = nil
                guard !self.pointerInside() else { return }
                self.lastDismissal = ProcessInfo.processInfo.systemUptime
                self.close()
                self.onClose?()
            }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }

    private func pointerInside() -> Bool {
        guard let panel = popover?.contentViewController?.view.window,
              let anchor, let window = anchor.window else { return false }
        let button = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        return BarLayout.keepsStripOpen(point: NSEvent.mouseLocation, panel: panel.frame, button: button)
    }

    private func clearHover() {
        hoverWork?.cancel(); hoverWork = nil
        hoverIndex = nil
        if let panel = hoverPanel { panel.parent?.removeChildWindow(panel); panel.orderOut(nil) }
        hoverPanel = nil
    }

    private func updateHover() {
        let point = NSEvent.mouseLocation
        guard let window = popover?.contentViewController?.view.window, window.frame.contains(point) else {
            clearHover()
            return
        }
        let index = buttons.firstIndex { button in
            guard let window = button.window, !button.visibleRect.isEmpty else { return false }
            return window.convertToScreen(button.convert(button.visibleRect, to: nil)).contains(point)
        }
        guard index != hoverIndex else { return }
        let wasVisible = hoverPanel != nil
        clearHover()
        guard let index else { return }
        hoverIndex = index
        let target = buttons[index]
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isShown, self.hoverIndex == index,
                  self.buttons.indices.contains(index), self.buttons[index] === target,
                  self.entries.indices.contains(index),
                  let parent = target.window, let screen = parent.screen else { return }
            let button = target
            let frame = parent.convertToScreen(button.convert(button.visibleRect, to: nil))
            guard !frame.isEmpty, frame.contains(NSEvent.mouseLocation) else { return }
            let title = self.displayTitle(at: index)
            let font = NSFont.systemFont(ofSize: 11)
            // Measure the full title explicitly before applying the display-width cap.
            let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
            let width = MenuBarDisplay.hoverWidth(textWidth: textWidth, screenWidth: screen.visibleFrame.width)
            let label = NSTextField(labelWithString: title)
            label.font = font
            label.lineBreakMode = .byTruncatingTail
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: 28),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.hasShadow = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.appearance = button.effectiveAppearance
            let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: 28))
            background.material = .toolTip
            background.state = .active
            background.wantsLayer = true
            background.layer?.cornerRadius = 6
            background.layer?.masksToBounds = true
            label.frame = NSRect(x: 10, y: 6, width: width - 20, height: 16)
            background.addSubview(label)
            panel.contentView = background
            panel.setAccessibilityElement(false)
            panel.setFrameOrigin(NSPoint(x: min(max(frame.midX - width / 2, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - width - 8),
                                         y: max(screen.visibleFrame.minY + 8, parent.frame.minY - 32)))
            parent.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)
            self.hoverPanel = panel
            self.hoverWork = nil
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (wasVisible ? 0 : 0.15), execute: work)
    }

    private func displayTitle(at index: Int) -> String {
        let entry = entries[index]
        let item = entry.display
        guard !MenuBarDisplay.isSystem(item) else { return MenuBarDisplay.title(item) }
        let peers = entries.filter { $0.pid == entry.pid && $0.launched == entry.launched }
        let peer = peers.firstIndex { CFEqual($0.element, entry.element) }.map { $0 + 1 } ?? 1
        return MenuBarDisplay.title(item, peer: peer, peers: peers.count)
    }

    private func grouped(_ values: [MenuBarEntry]) -> [MenuBarEntry] {
        guard let boundary else { return [] }
        return Array(values.filter {
            BarLayout.isHiddenGroup($0.frame, divider: boundary)
        }.prefix(128))
    }

    func popoverDidClose(_ notification: Notification) {
        guard let closing = notification.object as? NSPopover, closing === popover else { return }
        lastDismissal = ProcessInfo.processInfo.systemUptime
        close()
        onClose?()
    }

    private func base(width: CGFloat, height: CGFloat) -> NSView? {
        guard let controller = popover?.contentViewController else { return nil }
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        controller.view = view
        popover?.contentSize = view.frame.size
        // NSPopover centers itself again when loading expands into the icon row.
        // Realign after AppKit has applied the new content size.
        DispatchQueue.main.async { [weak self] in self?.alignToLeft() }
        return view
    }

    private func alignToLeft() {
        guard let popup = popover, popup.isShown,
              let window = popup.contentViewController?.view.window,
              let screen = anchorScreen else { return }
        let bounds = screen.frame.insetBy(dx: 8, dy: 0)
        let x = max(bounds.minX, min(anchorRight - window.frame.width, bounds.maxX - window.frame.width))
        window.setFrameOrigin(NSPoint(x: x, y: window.frame.minY))
    }

    private func setStripHelp(_ text: String) {
        popover?.contentViewController?.view.setAccessibilityHelp(text)
    }

    private func renderLoading() {
        if !MenuBarCatalog.trusted {
            guard let view = base(width: 360, height: 100) else { return }
            let text = NSTextField(wrappingLabelWithString: "需要辅助功能权限。已开启仍无效时，请移除旧条目并添加当前 TinyBar。")
            text.font = .systemFont(ofSize: 12)
            text.frame = NSRect(x: 12, y: 45, width: 336, height: 42)
            view.addSubview(text)
            let button = NSButton(title: "打开设置", target: self, action: #selector(openPermissionSettings))
            button.bezelStyle = .rounded
            button.frame = NSRect(x: 12, y: 9, width: 110, height: 28)
            view.addSubview(button)
            let done = NSButton(title: "重试", target: self, action: #selector(refresh))
            done.bezelStyle = .rounded
            done.frame = NSRect(x: 260, y: 9, width: 88, height: 28)
            view.addSubview(done)
        } else {
            guard let view = base(width: 180, height: 40) else { return }
            let text = NSTextField(labelWithString: "正在读取图标…")
            text.textColor = .secondaryLabelColor
            text.font = .systemFont(ofSize: 11)
            text.frame = NSRect(x: 12, y: 12, width: 156, height: 16)
            view.addSubview(text)
        }
    }

    private func load(preserveDisplayedEntries: Bool = false) {
        request?.cancel()
        generation += 1
        let expected = generation
        request = MenuBarCatalog.scan { [weak self] snapshot in
            guard let self, self.generation == expected, self.isShown else { return }
            guard self.groupBoundary?() == self.boundary else {
                self.cached = nil
                self.close()
                return
            }
            self.cached = snapshot
            self.cachedBoundary = self.boundary
            self.cachedAt = ProcessInfo.processInfo.systemUptime
            // Never move targets under a pointer while a cached strip is usable.
            // Keep this opening stable; the next opening uses the fresh snapshot.
            if preserveDisplayedEntries {
                self.setStripHelp("上次列表，重新打开查看更新；横向滚动查看更多")
                self.captureImages(fresh: snapshot.entries)
                return
            }
            self.entries = self.grouped(snapshot.entries)
            self.render(snapshot)
            self.captureImages(fresh: snapshot.entries)
        }
    }

    private func render(_ snapshot: CatalogSnapshot) {
        // One menu-bar-sized row; overflow scrolls rather than becoming a launcher.
        let pointerScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        let available = max(160, (pointerScreen ?? anchor?.window?.screen)?.visibleFrame.width ?? 800)
        let widths = entries.map { max(48, min(256, $0.frame.width * min(1, 28 / $0.frame.height)) + 8) }
        let permissionWidth: CGFloat
        if #available(macOS 14.0, *) { permissionWidth = CGPreflightScreenCaptureAccess() ? 0 : 100 }
        else { permissionWidth = 0 }
        let contentWidth = widths.reduce(0, +) + permissionWidth
        let width = min(max(180, contentWidth + 16), min(800, available - 32))
        guard let view = base(width: width, height: 40) else { return }
        clearHover()
        buttons.removeAll()
        let scroll = IconStripScrollView(frame: NSRect(x: 8, y: 4, width: width - 16, height: 32))
        // A scroller would overlap the small status-item hit targets.
        scroll.onScroll = { [weak self] in self?.clearHover(); self?.updateHover() }
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        let strip = NSView(frame: NSRect(x: 0, y: 0, width: max(contentWidth, scroll.frame.width), height: 32))
        var x: CGFloat = permissionWidth
        for (index, entry) in entries.enumerated() {
            let button = NSButton(frame: NSRect(x: x, y: 2, width: widths[index], height: 28))
            x += widths[index]
            button.isBordered = false
            button.imagePosition = .noImage
            button.title = String(MenuBarDisplay.title(entry.display).prefix(8))
            button.font = .systemFont(ofSize: 10)
            (button.cell as? NSButtonCell)?.lineBreakMode = .byTruncatingTail
            button.setAccessibilityHelp("\(entry.appName) · \(entry.label) · 原图标尚未读取")
            if let image = imageCache.image(for: entry) {
                applyImage(image, to: button, entry: entry)
                button.setAccessibilityHelp("\(entry.appName) · \(entry.label) · 上次图标，正在更新")
            }
            button.setAccessibilityLabel(displayTitle(at: index))
            button.target = self
            button.action = #selector(selectEntry(_:))
            button.tag = index
            strip.addSubview(button)
            buttons.append(button)
        }
        if permissionWidth > 0 {
            let permission = NSButton(title: "启用原始图标", target: self, action: #selector(openCaptureSettings))
            permission.bezelStyle = .inline
            permission.frame = NSRect(x: 0, y: 2, width: permissionWidth, height: 28)
            permission.toolTip = "需要屏幕录制权限；只在展开时读取菜单栏窗口。授权后请退出并重新打开 TinyBar。"
            strip.addSubview(permission)
        }
        scroll.documentView = strip
        view.addSubview(scroll)
        DispatchQueue.main.async { [weak self] in self?.updateHover() }
        setStripHelp(snapshot.incomplete == 0
            ? "原图标未读到时显示名称 · 横向滚动查看更多"
            : "原图标未读到时显示名称 · 部分项目未读到，重新打开重试 · 横向滚动查看更多")
        if entries.isEmpty && permissionWidth == 0 {
            let empty = NSButton(title: "未读到图标，点击重试", target: self, action: #selector(refresh))
            empty.isBordered = false
            empty.font = .systemFont(ofSize: 11)
            empty.frame = scroll.bounds
            strip.addSubview(empty)
        }
    }

    private func captureImages(fresh: [MenuBarEntry]) {
        imageTask?.cancel()
        guard #available(macOS 14.0, *), CGPreflightScreenCaptureAccess() else { return }
        let expected = generation
        let shown = entries
        let targets = buttons.map(ObjectIdentifier.init)
        // Never capture at a cached position. Reconcile with this opening's scan.
        var slots: [Int] = []
        var current: [MenuBarEntry] = []
        for (slot, old) in shown.enumerated() {
            if let entry = fresh.first(where: { old.matchesImageIdentity($0) }) {
                slots.append(slot)
                current.append(entry)
            } else {
                buttons[slot].setAccessibilityHelp("\(old.appName) · 项目已变化，重新展开更新" +
                    (buttons[slot].image != nil ? "；显示上次图标" : ""))
                buttons[slot].alphaValue = 0.65
            }
        }
        imageTask = Task { [weak self] in
            await StatusImages.shared.read(current) { [weak self] index, image, detail in
                guard let self, self.isShown, self.generation == expected,
                      slots.indices.contains(index) else { return }
                let slot = slots[index]
                guard self.buttons.indices.contains(slot),
                      ObjectIdentifier(self.buttons[slot]) == targets[slot] else { return }
                let button = self.buttons[slot]
                button.setAccessibilityHelp("\(shown[slot].appName) · \(shown[slot].label) · \(detail)" +
                    (image == nil && button.image != nil ? "；显示上次图标" : ""))
                guard let image else {
                    if button.image != nil { button.alphaValue = 0.65 }
                    return
                }
                self.imageCache.insert(image, for: current[index])
                self.applyImage(image, to: button, entry: current[index])
            }
        }
    }

    private func applyImage(_ image: CGImage, to button: NSButton, entry: MenuBarEntry) {
        let scale = min(1, 28 / entry.frame.height)
        button.image = NSImage(cgImage: image, size: NSSize(width: entry.frame.width * scale, height: entry.frame.height * scale))
        button.imagePosition = .imageOnly
        button.alphaValue = 1
    }

    @objc private func openCaptureSettings() {
        close()
        // An explicit button action is the only permission-requesting path.
        _ = CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func selectEntry(_ sender: NSButton) {
        guard entries.indices.contains(sender.tag), buttons.indices.contains(sender.tag),
              buttons[sender.tag] === sender else { return }
        guard let window = sender.window, let screen = window.screen, !sender.visibleRect.isEmpty else { return }
        let target = SelectionAnchor(rect: window.convertToScreen(sender.convert(sender.visibleRect, to: nil)),
                                     visibleFrame: screen.visibleFrame)
        let entry = entries[sender.tag]
        close()
        onSelect?(entry, target)
    }

    @objc private func refresh() {
        clearHover()
        request?.cancel(); request = nil; generation += 1
        cached = nil
        imageCache.clear()
        entries.removeAll(); imageTask?.cancel(); imageTask = nil; buttons.removeAll()
        renderLoading()
        if MenuBarCatalog.trusted { load() }
    }
    @objc private func openPermissionSettings() {
        // The user must enable permission in System Settings. Never change TCC ourselves.
        close()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

private final class IconStripScrollView: NSScrollView {
    var onScroll: (() -> Void)?
    override func scrollWheel(with event: NSEvent) {
        guard let documentView else { return }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX : event.scrollingDeltaY
        let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 16
        let limit = max(0, documentView.frame.width - contentView.bounds.width)
        let x = min(limit, max(0, contentView.bounds.minX - delta * scale))
        contentView.scroll(to: NSPoint(x: x, y: 0))
        reflectScrolledClipView(contentView)
        onScroll?()
    }
}

private extension MenuBarEntry {
    var display: MenuBarDisplay.Item {
        MenuBarDisplay.Item(appName: appName, label: label, hasOwnLabel: hasOwnLabel,
                            identifier: identifier, bundleID: bundleID, ordinal: ordinal)
    }
}
