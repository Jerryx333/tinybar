import AppKit

@main enum CatalogProbe {
    static func main() {
        // Diagnostic uses its launcher's TCC context. It proves enumeration only,
        // never installed-app authorization or successful menu interaction.
        guard MenuBarCatalog.trusted else { fputs("No Accessibility permission in this test context\n", stderr); exit(77) }
        for _ in 0..<50 {
            let cancelled = MenuBarCatalog.scan { _ in
                fputs("Cancelled request delivered a stale result\n", stderr); exit(1)
            }
            cancelled.cancel()
        }
        let start = ProcessInfo.processInfo.systemUptime
        let request = MenuBarCatalog.scan { result in
            let pids = Set(result.entries.map(\.pid))
            print("entries=\(result.entries.count) apps=\(pids.count) incomplete=\(result.incomplete) elapsed=\(ProcessInfo.processInfo.systemUptime-start)")
            precondition(result.entries.allSatisfy { $0.frame.width > 0 && $0.frame.height > 0 })
            precondition(result.entries.count <= 512 * 256)
            precondition(MenuBarCatalog.queue.operationCount == 0, "Pending operations leaked after completion")
            exit(result.entries.isEmpty ? 1 : 0)
        }
        withExtendedLifetime(request) { RunLoop.main.run(until: Date().addingTimeInterval(6)) }
        fputs("Catalog completion timed out\n", stderr)
        exit(1)
    }
}
