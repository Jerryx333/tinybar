import AppKit

// Separate fixture process stays alive while the manager quits or crashes.
final class Survivor: NSObject, NSApplicationDelegate {
    var items: [NSStatusItem] = []
    var timer: Timer?
    var visibleSamples = 0
    var hiddenSamples = 0
    var hiddenConsecutive = 0
    var restoredSamples = 0
    var initial: [NSRect] = []
    let start = ProcessInfo.processInfo.systemUptime
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard CommandLine.arguments.count == 2 else { fputs("Usage: Survivor REPORT\n", stderr); exit(64) }
        for index in 0..<3 {
            let item = NSStatusBar.system.statusItem(withLength: 24)
            item.button?.title = "S\(index)"
            items.append(item)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.sample() }
    }
    func sample() {
        let frames = items.compactMap { $0.button?.window?.frame }
        let visible = frames.count == items.count && frames.allSatisfy { BarLayout.controlScreen($0, screens: NSScreen.screens.map(\.frame)) != nil }
        let hidden = frames.count == items.count && frames.allSatisfy { rect in !NSScreen.screens.contains { $0.frame.intersects(rect) } }
        if visible && hiddenSamples == 0 { visibleSamples += 1; initial = frames }
        if visibleSamples >= 5 && hidden { hiddenSamples += 1; hiddenConsecutive += 1 }
        else if hiddenConsecutive < 5 { hiddenConsecutive = 0 }
        if hiddenConsecutive >= 5 && visible { restoredSamples += 1 }
        else { restoredSamples = 0 }
        if restoredSamples >= 5 {
            let result: [String: Any] = ["result": "restored after recovery action", "initial_frames": initial.map(NSStringFromRect),
                                       "final_frames": frames.map(NSStringFromRect), "visible_samples": visibleSamples,
                                       "hidden_samples": hiddenSamples, "restored_samples": restoredSamples]
            do { try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted,.sortedKeys]).write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic) }
            catch { fputs("Write failed: \(error)\n", stderr); exit(1) }
            print("Survivor: hidden items visible again after recovery action")
            NSApp.terminate(nil)
        }
        if ProcessInfo.processInfo.systemUptime - start > 45 { fputs("Survivor timed out\n",stderr); exit(1) }
    }
}
@main enum SurvivorMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = Survivor()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}
