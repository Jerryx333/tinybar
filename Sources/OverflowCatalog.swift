import AppKit
import ApplicationServices

struct MenuBarEntry {
    let element: AXUIElement
    let pid: pid_t
    let launched: Date?
    let appName: String
    let label: String
    let identifier: String?
    let frame: CGRect // Accessibility coordinates, not AppKit coordinates.
    let ordinal: Int
    var bundleID: String? = nil
    var hasOwnLabel = true // false when label is the "<app> · <n>" fallback.

    // Image identity is independent of the current screen position.
    func matchesImageIdentity(_ other: MenuBarEntry) -> Bool {
        pid == other.pid && launched == other.launched && identifier == other.identifier &&
            frame.size == other.frame.size && CFEqual(element, other.element)
    }
}

struct CatalogSnapshot {
    let entries: [MenuBarEntry]
    let incomplete: Int
}

// One opened panel owns one request. Closing cancels future IPC calls; an already
// running synchronous AX call finishes under its per-element messaging timeout.
final class CatalogRequest {
    private let lock = NSLock()
    private var cancelled = false
    private var entries: [MenuBarEntry] = []
    private var incomplete = 0
    let deadline = ProcessInfo.processInfo.systemUptime + 3
    func cancel() { lock.lock(); cancelled = true; entries.removeAll(); lock.unlock() }
    var active: Bool { lock.lock(); defer { lock.unlock() }; return !cancelled }
    var withinDeadline: Bool { active && ProcessInfo.processInfo.systemUptime < deadline }
    func append(_ values: [MenuBarEntry], incomplete: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { return }
        entries.append(contentsOf: values)
        if incomplete { self.incomplete += 1 }
    }
    func snapshot() -> CatalogSnapshot {
        lock.lock(); defer { lock.unlock() }
        return CatalogSnapshot(entries: entries.sorted {
            let row0 = Int(($0.frame.minY / 32).rounded()), row1 = Int(($1.frame.minY / 32).rounded())
            if row0 != row1 { return row0 < row1 }
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            return $0.pid != $1.pid ? $0.pid < $1.pid : $0.ordinal < $1.ordinal
        }, incomplete: incomplete)
    }
}

enum MenuBarCatalog {
    private struct ReadError: Error { let code: AXError }
    static var trusted: Bool { AXIsProcessTrusted() }
    static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "TinyBar.on-demand-accessibility"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    private static let actionQueue = DispatchQueue(label: "TinyBar.menu-action", qos: .userInitiated)
    private static var actionInFlight = false // Main-thread owned.
    private static let attributes = [kAXTitleAttribute, kAXDescriptionAttribute, kAXIdentifierAttribute,
                                     kAXPositionAttribute, kAXSizeAttribute, kAXEnabledAttribute] as CFArray

    private static func values(_ element: AXUIElement) -> Result<[Any], ReadError> {
        AXUIElementSetMessagingTimeout(element, 0.12)
        var result: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(element, attributes, [], &result)
        guard error == .success, let result else { return .failure(ReadError(code: error)) }
        return .success(result as [AnyObject])
    }

    private static func rect(_ values: [Any]) -> CGRect? {
        guard values.count >= 5, CFGetTypeID(values[3] as CFTypeRef) == AXValueGetTypeID(),
              CFGetTypeID(values[4] as CFTypeRef) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(values[3] as! AXValue, .cgPoint, &point),
              AXValueGetValue(values[4] as! AXValue, .cgSize, &size),
              point.x.isFinite, point.y.isFinite, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: point, size: size)
    }

    static func ownLabel(_ values: [Any]) -> String? {
        let description = (values.count > 1 ? values[1] as? String : nil)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = (values.first as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = !description.isEmpty ? description : title
        return text.isEmpty ? nil : String(text.prefix(160))
    }

    static func label(_ values: [Any], fallback: String, ordinal: Int) -> String {
        ownLabel(values) ?? String("\(fallback) · \(ordinal + 1)".prefix(160))
    }

    @discardableResult
    static func scan(completion: @escaping (CatalogSnapshot) -> Void) -> CatalogRequest {
        let request = CatalogRequest()
        guard trusted else { DispatchQueue.main.async { if request.active { completion(CatalogSnapshot(entries: [], incomplete: 1)) } }; return request }
        // macOS 26 proxies menu-bar windows through Control Center, so window owner
        // PIDs alone cannot enumerate the original items. Query each live app once.
        let apps = NSWorkspace.shared.runningApplications.filter {
            !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        let bounded = Array(apps.prefix(512))
        if apps.count > bounded.count { request.append([], incomplete: true) }
        let group = DispatchGroup()
        for app in bounded {
            group.enter()
            queue.addOperation {
                defer { group.leave() }
                autoreleasepool {
                    guard request.withinDeadline else { request.append([], incomplete: true); return }
                    let element = AXUIElementCreateApplication(app.processIdentifier)
                    AXUIElementSetMessagingTimeout(element, 0.12)
                    var extras: CFTypeRef?
                    let result = AXUIElementCopyAttributeValue(element, kAXExtrasMenuBarAttribute as CFString, &extras)
                    if result == .attributeUnsupported || result == .noValue { return }
                    guard result == .success, let extras, CFGetTypeID(extras) == AXUIElementGetTypeID() else {
                        request.append([], incomplete: true); return
                    }
                    let menu = extras as! AXUIElement
                    AXUIElementSetMessagingTimeout(menu, 0.12)
                    var count: CFIndex = 0
                    guard AXUIElementGetAttributeValueCount(menu, kAXChildrenAttribute as CFString, &count) == .success else { request.append([], incomplete: true); return }
                    guard count > 0 else { return }
                    var children: CFArray?
                    guard AXUIElementCopyAttributeValues(menu, kAXChildrenAttribute as CFString, 0, min(count, 256), &children) == .success,
                          let items = children as? [AXUIElement] else { request.append([], incomplete: true); return }
                    var found: [MenuBarEntry] = []
                    var incomplete = count > items.count
                    for (ordinal, item) in items.enumerated() {
                        guard request.withinDeadline else { incomplete = true; break }
                        switch values(item) {
                        case .success(let value):
                            // Control Center contains disabled zero-sized placeholders. They are
                            // not displayed menu-bar items. Offscreen nonzero items ARE retained.
                            guard let frame = rect(value) else { continue }
                            let name = app.localizedName ?? "菜单栏项目"
                            let own = ownLabel(value)
                            found.append(MenuBarEntry(element: item, pid: app.processIdentifier, launched: app.launchDate,
                                                      appName: name, label: own ?? label(value, fallback: name, ordinal: ordinal),
                                                      identifier: value[2] as? String, frame: frame, ordinal: ordinal,
                                                      bundleID: app.bundleIdentifier, hasOwnLabel: own != nil))
                        case .failure: incomplete = true
                        }
                    }
                    request.append(found, incomplete: incomplete)
                }
            }
        }
        group.notify(queue: .main) {
            guard request.active else { return }
            completion(request.snapshot())
        }
        return request
    }

    enum ActionResult { case sent, unknown, unavailable(String) }

    static func press(_ entry: MenuBarEntry, completion: @escaping (ActionResult) -> Void) {
        precondition(Thread.isMainThread)
        guard !actionInFlight else { completion(.unavailable("上一个菜单操作尚未结束。")); return }
        guard trusted else { completion(.unavailable("请在系统设置中允许 TinyBar 的辅助功能权限。")); return }
        actionInFlight = true
        actionQueue.async {
            let result: ActionResult = autoreleasepool {
                guard let app = NSRunningApplication(processIdentifier: entry.pid), !app.isTerminated,
                      app.launchDate == entry.launched else { return .unavailable("应用已退出或重启，请重新打开浮层。") }
                var pid: pid_t = 0
                guard AXUIElementGetPid(entry.element, &pid) == .success, pid == entry.pid else {
                    return .unavailable("菜单栏项目已变化，请重新打开浮层。")
                }
                let current: [Any]
                switch values(entry.element) {
                case .success(let value): current = value
                case .failure(let error):
                    return .unavailable(error.code == .cannotComplete ? "应用未响应，请稍后再试。" : "项目不可用，请检查权限或重新打开浮层。")
                }
                guard rect(current) != nil, entry.identifier == nil || current[2] as? String == entry.identifier else {
                    return .unavailable("菜单栏项目已变化，请重新打开浮层。")
                }
                // The exact retained AX element must still belong to this live app's
                // menu bar. Dynamic titles (clock/CPU/network) are not identity.
                let root = AXUIElementCreateApplication(entry.pid)
                AXUIElementSetMessagingTimeout(root, 0.12)
                var menuValue: CFTypeRef?
                guard AXUIElementCopyAttributeValue(root, kAXExtrasMenuBarAttribute as CFString, &menuValue) == .success,
                      let menuValue, CFGetTypeID(menuValue) == AXUIElementGetTypeID() else {
                    return .unavailable("应用菜单栏未响应，请稍后再试。")
                }
                let menu = menuValue as! AXUIElement
                AXUIElementSetMessagingTimeout(menu, 0.12)
                var count: CFIndex = 0
                var children: CFArray?
                guard AXUIElementGetAttributeValueCount(menu, kAXChildrenAttribute as CFString, &count) == .success,
                      AXUIElementCopyAttributeValues(menu, kAXChildrenAttribute as CFString, 0, min(count, 256), &children) == .success,
                      let items = children as? [AXUIElement], items.contains(where: { CFEqual($0, entry.element) }) else {
                    return .unavailable("原菜单栏项目已移除，请重新打开浮层。")
                }
                var actions: CFArray?
                guard AXUIElementCopyActionNames(entry.element, &actions) == .success,
                      (actions as? [String])?.contains(kAXPressAction) == true else {
                    return .unavailable("此项目没有提供可用的菜单操作。")
                }
                AXUIElementSetMessagingTimeout(entry.element, 0.4)
                switch AXUIElementPerformAction(entry.element, kAXPressAction as CFString) {
                case .success: return .sent
                // Some apps enter menu tracking before replying. Retrying could close
                // a successfully opened menu. Never infer failure or automatically retry.
                case .cannotComplete: return .unknown
                case .apiDisabled: return .unavailable("辅助功能权限已撤销，请重新允许后再试。")
                default: return .unavailable("应用未接受菜单操作，请重新打开浮层后再试。")
                }
            }
            DispatchQueue.main.async { actionInFlight = false; completion(result) }
        }
    }
}
