import AppKit


// One-shot original window snapshots, including offscreen menu-bar windows.
// Never capture a display, start a stream, or write screenshots to disk.
@available(macOS 14.0, *)
actor StatusImages {
    static let shared = StatusImages()
    private var inFlight = false
    static func sameFrame(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 1 && abs(a.minY - b.minY) <= 1 &&
        abs(a.width - b.width) <= 1 && abs(a.height - b.height) <= 1
    }

    static func containsItem(_ window: CGRect, _ item: CGRect) -> Bool {
        // AX describes the button, while WindowServer includes menu-bar padding.
        window.insetBy(dx: -1, dy: -1).contains(item) &&
            abs(window.midX - item.midX) <= 1 && abs(window.midY - item.midY) <= 2 &&
            window.width - item.width <= 20 && window.height - item.height <= 16
    }

    func read(_ entries: [MenuBarEntry],
                               deliver: @MainActor (Int, CGImage?, String) -> Void) async {
        guard CGPreflightScreenCaptureAccess() else { return }
        guard !inFlight else {
            for i in entries.indices {
                guard !Task.isCancelled else { return }
                await deliver(i, nil, "上次系统截图尚未结束；稍后重新展开，持续无响应请重启 TinyBar")
            }
            return
        }
        inFlight = true
        defer { inFlight = false }
        let windows = Self.windows()
        let deadline = ProcessInfo.processInfo.systemUptime + 4
        // Serial captures keep transient image memory bounded. Stop starting work
        // on close or after the deadline; a pending OS screenshot may finish later.
        for (i, entry) in entries.prefix(128).enumerated() {
            guard !Task.isCancelled else { return }
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                await deliver(i, nil, "本次图标读取超时，重新展开重试"); continue
            }
            guard entry.frame.width <= 256, entry.frame.height <= 64,
                  entries.filter({ Self.sameFrame($0.frame, entry.frame) }).count == 1 else {
                await deliver(i, nil, "图标位置不唯一或尺寸超限"); continue
            }
            let matches = windows.filter { window in
                Self.containsItem(window.frame, entry.frame) &&
                    (window.pid == entry.pid || window.isProxy)
            }
            guard matches.count == 1, let window = matches.first else {
                await deliver(i, nil, "系统未提供可唯一对应的原图标"); continue
            }
            guard currentFrame(entry).map({ Self.sameFrame($0, entry.frame) }) == true else {
                await deliver(i, nil, "图标位置已变化，请重新展开"); continue
            }
            // This public window-list API can read windows entirely outside the
            // display. SCK returns errors/transparent pixels for those windows.
            // Keep synchronous WindowServer work off the cooperative executor.
            let captured = await Self.capture(window)
            guard !Task.isCancelled else { return }
            guard let after = captured.1,
                  after.pid == window.pid, after.launched == window.launched,
                  after.title == window.title, Self.sameFrame(after.frame, window.frame),
                  currentFrame(entry).map({ Self.sameFrame($0, entry.frame) }) == true else {
                await deliver(i, nil, "图标位置或所属应用已变化，请重新展开"); continue
            }
            guard let image = captured.0 else {
                await deliver(i, nil, "系统无法读取此原图标"); continue
            }
            let sx = CGFloat(image.width) / window.frame.width
            let sy = CGFloat(image.height) / window.frame.height
            guard (abs(sx - 1) < 0.01 || abs(sx - 2) < 0.01), abs(sx - sy) < 0.01 else {
                await deliver(i, nil, "原图标缩放比例不一致"); continue
            }
            let crop = CGRect(x: (entry.frame.minX - window.frame.minX) * sx,
                              y: (entry.frame.minY - window.frame.minY) * sy,
                              width: entry.frame.width * sx, height: entry.frame.height * sy).integral
                .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let cropped = image.cropping(to: crop), hasPixels(cropped) else {
                await deliver(i, nil, "原图标裁剪区域不可用"); continue
            }
            await deliver(i, cropped, "原始状态栏图标（展开时快照）")
        }
        for i in entries.indices.dropFirst(128) {
            guard !Task.isCancelled else { return }
            await deliver(i, nil, "本次图标数量超过读取上限")
        }
    }

    private struct Window {
        let id: CGWindowID
        let pid: pid_t
        let launched: Date?
        let title: String?
        let frame: CGRect
        let isProxy: Bool
    }
    private static func windows() -> [Window] {
        guard let values = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return values.compactMap(parseWindow)
    }
    private static func parseWindow(_ value: [String: Any]) -> Window? {
            guard value[kCGWindowLayer as String] as? Int == 25,
                  let id = value[kCGWindowNumber as String] as? UInt32,
                  let pid = value[kCGWindowOwnerPID as String] as? Int32, pid != getpid(),
                  let bounds = value[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  frame.minX.isFinite, frame.minY.isFinite,
                  frame.width > 0, frame.width <= 276, frame.height > 0, frame.height <= 80,
                  let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return nil }
            return Window(id: id, pid: pid, launched: app.launchDate,
                          title: value[kCGWindowName as String] as? String, frame: frame,
                          isProxy: app.bundleIdentifier == "com.apple.controlcenter")
    }
    private static let captureQueue = DispatchQueue(label: "TinyBar.window-snapshot", qos: .userInitiated)
    private static func capture(_ window: Window) async -> (CGImage?, Window?) {
        await withCheckedContinuation { continuation in
            captureQueue.async {
                let result: (CGImage?, Window?) = autoreleasepool {
                    var raw = UnsafeRawPointer(bitPattern: UInt(window.id))
                    guard let array = CFArrayCreate(kCFAllocatorDefault, &raw, 1, nil) else { return (nil, nil) }
                    let image = windowSnapshot(CGImage.self, ids: array)
                    let values = CGWindowListCreateDescriptionFromArray(array) as? [[String: Any]]
                    let after = values?.first.flatMap(parseWindow)
                    return (image, after)
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func currentFrame(_ entry: MenuBarEntry) -> CGRect? {
        guard let app = NSRunningApplication(processIdentifier: entry.pid),
              !app.isTerminated, app.launchDate == entry.launched else { return nil }
        AXUIElementSetMessagingTimeout(entry.element, 0.05)
        var p: CFTypeRef?, s: CFTypeRef?
        guard AXUIElementCopyAttributeValue(entry.element, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(entry.element, kAXSizeAttribute as CFString, &s) == .success,
              let p, let s, CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    private func hasPixels(_ image: CGImage) -> Bool {
        guard image.width <= 512, image.height <= 128 else { return false }
        let count = image.width * image.height * 4
        var pixels = [UInt8](repeating: 0, count: count)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let ctx = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return stride(from: 3, to: count, by: 4).contains { bytes[$0] > 16 }
        }
    }
}

// The SDK deprecates this public API in favor of SCK; SCK cannot read fully
// offscreen status windows. Keep the compatibility call at this single boundary.
private protocol WindowSnapshot {
    init?(windowListFromArrayScreenBounds: CGRect, windowArray: CFArray, imageOption: CGWindowImageOption)
}
extension CGImage: WindowSnapshot {}
private func windowSnapshot<T: WindowSnapshot>(_ type: T.Type, ids: CFArray) -> T? {
    T(windowListFromArrayScreenBounds: .null, windowArray: ids,
      imageOption: [.boundsIgnoreFraming, .bestResolution])
}
