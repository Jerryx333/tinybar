import AppKit

// Compiled only with -D TESTING into a different bundle/defaults domain.
// Drives production methods with real NSStatusItem windows, no synthesized input.
enum Probe {
    static var items: [NSStatusItem] = []
    static var initial: [NSRect] = []
    static var round = 0
    static var begun = ProcessInfo.processInfo.systemUptime
    static var mode = "integration"
    static var report = ""

    static func runIfRequested(_ bar: TinyBar) -> Bool {
        let args = CommandLine.arguments
        guard args.count == 4, args[1] == "--probe", ["integration", "reversed", "hold"].contains(args[2]) else {
            fputs("Test app requires --probe integration|reversed|hold REPORT\n", stderr); exit(64)
        }
        mode = args[2]; report = args[3]; begun = ProcessInfo.processInfo.systemUptime
        later(40) { require(false, "Probe timed out") }
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        if mode == "reversed" {
            UserDefaults.standard.set(300.0, forKey: "NSStatusItem Preferred Position TinyBar.Control")
            UserDefaults.standard.set(180.0, forKey: "NSStatusItem Preferred Position TinyBar.Divider")
        }
        bar.createItems()
        bar.watchEvents()
        for index in 0..<5 {
            let name = "Fixture.\(index)"
            UserDefaults.standard.set(270.0 + Double(index) * 45, forKey: "NSStatusItem Preferred Position \(name)")
            let item = NSStatusBar.system.statusItem(withLength: 28)
            item.autosaveName = name
            item.button?.title = "\(index)"
            items.append(item)
        }
        later(1.5) {
            require(!bar.managerConflict(), "Quit other menu-bar managers before integration tests")
            initial = items.map { $0.button!.window!.frame }
            if mode == "reversed" {
                let c = bar.control.button!.window!.frame, d = bar.divider.button!.window!.frame
                require(onScreen(c) && onScreen(d) && !BarLayout.ordered(control: c, divider: d), "Reversed fixture preconditions failed: control=\(c), divider=\(d)")
                require(!bar.hide() && !bar.collapsed && bar.issue != nil, "Reversed anchors were accepted")
                require(bar.issue!.contains("分隔线放在"), "Rejected for a different reason: \(bar.issue!)")
                bar.resetPosition()
                later(0.5) {
                    require(bar.hide(), "Reset did not restore valid order: \(bar.issue ?? "unknown")")
                    later(0.5) {
                        require(bar.collapsed, "Reset layout rejected by settled check")
                        finish(bar, result: "reversed-order rejected; reset restored")
                    }
                }
            } else {
                require(initial.allSatisfy(onScreen), "Fixture items not initially visible; free menu-bar space first")
                cycle(bar)
            }
        }
        return true
    }

    static func onScreen(_ rect: NSRect) -> Bool { BarLayout.controlScreen(rect, screens: NSScreen.screens.map(\.frame)) != nil }
    static func require(_ condition: Bool, _ message: String) {
        guard condition else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    static func later(_ delay: Double, _ block: @escaping () -> Void) { DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block) }
    static func cycle(_ bar: TinyBar) {
        let before = bar.control.button!.window!.frame
        require(bar.hide(), "Hide rejected: \(bar.issue ?? "unknown")")
        later(0.5) {
            require(bar.collapsed, "Safety check rejected collapse: \(bar.issue ?? "unknown")")
            require(onScreen(bar.control.button!.window!.frame), "Control left the screen")
            require(bar.control.button!.window!.frame == before, "Control moved during hiding")
            require(items.allSatisfy { item in !NSScreen.screens.contains { $0.frame.intersects(item.button!.window!.frame) } }, "Fixture items did not fully leave screens")
            if mode == "hold" {
                write(["result": "collapsed", "pid": ProcessInfo.processInfo.processIdentifier])
                return
            }
            bar.reveal()
            require(bar.hide(), "Immediate reveal/hide failed: \(bar.issue ?? "unknown"), control=\(String(describing: bar.control.button?.window?.frame)), divider=\(String(describing: bar.divider.button?.window?.frame))")
            bar.reveal()
            later(0.3) {
                let current = items.map { $0.button!.window!.frame }
                require(current.allSatisfy(onScreen), "Revealed fixture is not fully onscreen")
                let translation = current[0].minX - initial[0].minX
                require(zip(initial, current).allSatisfy { abs(($1.minX - $0.minX) - translation) <= 1 }, "Item arrangement did not restore: initial=\(initial.map(NSStringFromRect)), current=\(current.map(NSStringFromRect))")
                round += 1
                if round < 20 { cycle(bar) } else { testRecovery(bar) }
            }
        }
    }
    static func testRecovery(_ bar: TinyBar) {
        require(bar.hide(), "Recovery precondition failed")
        later(0.5) {
            require(bar.collapsed, "Queue test precondition did not settle")
            bar.reveal()
            require(bar.hide() && !bar.collapsed, "Immediate hide was not queued")
            later(0.6) {
                require(bar.collapsed, "Queued hide never completed")
                require(items.allSatisfy { item in !NSScreen.screens.contains { $0.frame.intersects(item.button!.window!.frame) } }, "Queued hide did not fully hide fixtures")
                testEvents(bar)
            }
        }
    }
    static func testEvents(_ bar: TinyBar) {
        // The public reopen delegate is tested here; LaunchServices delivery is checked separately.
        _ = bar.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
        require(!bar.collapsed, "Reopen did not reveal")
        later(0.4) {
            require(items.allSatisfy { onScreen($0.button!.window!.frame) }, "Reopen did not restore fixture frames")
            require(bar.hide(), "Event test hide failed")
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
            require(!bar.collapsed, "Screen notification did not reveal")
            later(0.4) {
                require(items.allSatisfy { onScreen($0.button!.window!.frame) }, "Screen event did not restore frames")
                require(bar.hide(), "Wake test hide failed")
                NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
                require(!bar.collapsed, "Wake notification did not reveal")
                later(0.4) {
                    require(items.allSatisfy { onScreen($0.button!.window!.frame) }, "Wake event did not restore frames")
                    require(bar.hide(), "Failed-postcheck test could not collapse")
                    bar.divider.length = BarLayout.dividerWidth // Simulate OS rejecting an oversized item.
                    later(0.5) {
                        require(!bar.collapsed && bar.issue != nil, "Failed layout postcheck did not reveal")
                        finish(bar, result: "passed")
                    }
                }
            }
        }
    }
    static func write(_ value: [String: Any]) {
        do { try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: report), options: .atomic) }
        catch { fputs("Report failed: \(error)\n", stderr); exit(1) }
    }
    static func finish(_ bar: TinyBar, result: String) {
        write(["result": result, "cycles": round, "elapsed_seconds": ProcessInfo.processInfo.systemUptime - begun,
               "screen_count": NSScreen.screens.count, "initial_fixture_frames": initial.map(NSStringFromRect)])
        print("Probe: \(result), \(round) cycles")
        NSApp.terminate(nil)
    }
}
