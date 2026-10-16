import Foundation
import CoreGraphics

// Pure hover-name rules. Classification uses bundle IDs and AX identifiers only;
// localized app names ("控制中心", "Control Center") are never identity.
enum MenuBarDisplay {
    static let controlCenterBundleID = "com.apple.controlcenter"
    static let systemExtraPrefix = "com.apple.menuextra."
    // Used only when a known system item has no AX title/description of its own.
    private static let knownExtras: [String: String] = [
        "bluetooth": "蓝牙", "wifi": "Wi-Fi", "battery": "电池", "sound": "声音",
        "clock": "时钟", "focusmode": "专注模式", "now-playing": "正在播放",
        "screen-mirroring": "屏幕镜像", "user": "用户", "controlcenter": "控制中心",
    ]

    struct Item {
        var appName: String
        var label: String
        var hasOwnLabel = true
        var identifier: String? = nil
        var bundleID: String? = nil
        var ordinal = 0
    }

    static func isSystem(_ item: Item) -> Bool {
        item.identifier?.hasPrefix(systemExtraPrefix) == true || item.bundleID == controlCenterBundleID
    }

    /// `peer` is this item's 1-based position among displayed items of the same process.
    static func title(_ item: Item, peer: Int = 1, peers: Int = 1) -> String {
        let label = item.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if isSystem(item) {
            if item.hasOwnLabel && !label.isEmpty { return label }
            if let identifier = item.identifier, identifier.hasPrefix(systemExtraPrefix) {
                let key = String(identifier.dropFirst(systemExtraPrefix.count))
                return knownExtras[key] ?? "系统项目（\(key)）"
            }
            // No identifier and no name: the owner is a proxy, the real source is unknown.
            return "未识别的菜单栏项目 · \(item.ordinal + 1)"
        }
        let app = item.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        var title = app.isEmpty ? "未知应用" : app
        if peers > 1 { title += " · \(peer)/\(peers)" }
        if item.hasOwnLabel && !label.isEmpty && label != app { title += " · " + label }
        return title
    }

    /// Fits the measured single-line text width; long text is capped and tail-truncated.
    static func hoverWidth(textWidth: CGFloat, screenWidth: CGFloat, padding: CGFloat = 20, maximum: CGFloat = 360) -> CGFloat {
        let fitted = (textWidth.isFinite ? max(0, textWidth) : maximum).rounded(.up) + padding + 2
        return max(padding + 16, min(fitted, maximum, screenWidth - 16))
    }
}
