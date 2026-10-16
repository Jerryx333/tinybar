import AppKit

// Main-thread owned, bounded snapshots; no timers, disk files or active capture.
final class StatusImageCache {
    private struct Item {
        let entry: MenuBarEntry
        let image: CGImage
        let time: TimeInterval
        let cost: Int
    }
    private var items: [Item] = []
    private(set) var bytes = 0
    private let budget: Int
    private let lifetime: TimeInterval
    init(budget: Int = 4 * 1024 * 1024, lifetime: TimeInterval = 300) {
        self.budget = budget
        self.lifetime = lifetime
    }
    func clear() { items.removeAll(); bytes = 0 }
    private func prune(_ now: TimeInterval) {
        items.removeAll { now - $0.time >= lifetime }
        bytes = items.reduce(0) { $0 + $1.cost }
    }
    func image(for entry: MenuBarEntry, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> CGImage? {
        prune(now)
        return items.first { $0.entry.matchesImageIdentity(entry) }?.image
    }
    func insert(_ image: CGImage, for entry: MenuBarEntry,
                now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        prune(now)
        let (rowBytes, rowOverflow) = image.width.multipliedReportingOverflow(by: 4)
        let (cost, overflow) = rowBytes.multipliedReportingOverflow(by: image.height)
        guard !rowOverflow, !overflow, cost > 0, cost <= budget else { return }
        let colorSpace = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        // Cropped CGImages can retain the larger parent buffer. Own a compact
        // allocation so the byte budget describes the memory actually retained.
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: rowBytes,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let copy = context.makeImage() else { return }
        let retainedCost = copy.bytesPerRow * copy.height
        guard retainedCost <= budget else { return }
        items.removeAll { $0.entry.matchesImageIdentity(entry) }
        bytes = items.reduce(0) { $0 + $1.cost }
        while !items.isEmpty && (bytes + retainedCost > budget || items.count >= 128) {
            bytes -= items.removeFirst().cost
        }
        items.append(Item(entry: entry, image: copy, time: now, cost: retainedCost))
        bytes += retainedCost
    }
}
