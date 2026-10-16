import AppKit
import ApplicationServices

@main enum ImageCacheTests {
    static func main() {
        let context = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8,
                                bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let image = context.makeImage()!
        let element = AXUIElementCreateApplication(getpid())
        func entry(_ id: String, _ launch: Date = Date(timeIntervalSince1970: 1), x: CGFloat = 0,
                   pid: pid_t = getpid(), size: CGFloat = 16,
                   ax: AXUIElement? = nil) -> MenuBarEntry {
            MenuBarEntry(element: ax ?? element, pid: pid, launched: launch, appName: "Fixture",
                         label: "dynamic label", identifier: id, frame: CGRect(x: x, y: 0, width: size, height: size), ordinal: 0)
        }
        let cache = StatusImageCache(budget: 2048, lifetime: 10)
        cache.insert(image, for: entry("a"), now: 0)
        precondition(cache.image(for: entry("a", x: 30), now: 1) != nil, "Moving the same item must retain its image")
        precondition(cache.image(for: entry("b"), now: 1) == nil, "Different item must not receive cached image")
        precondition(cache.image(for: entry("a", Date(timeIntervalSince1970: 2)), now: 1) == nil, "Restart must not reuse another process lifetime")
        precondition(cache.image(for: entry("a", pid: getpid() + 1), now: 1) == nil)
        precondition(cache.image(for: entry("a", size: 18), now: 1) == nil)
        precondition(cache.image(for: entry("a", ax: AXUIElementCreateSystemWide()), now: 1) == nil)
        cache.insert(image, for: entry("a", x: 40), now: 1)
        precondition(cache.bytes == 1024, "Replacement must not duplicate retained bytes")
        precondition(entry("a").matchesImageIdentity(entry("a", x: 100)), "Refresh reconciliation must ignore position")
        cache.insert(image, for: entry("b"), now: 2)
        cache.insert(image, for: entry("c"), now: 3)
        precondition(cache.bytes <= 2048 && cache.image(for: entry("a"), now: 3) == nil)
        precondition(cache.image(for: entry("c"), now: 13) == nil && cache.bytes == 0, "Expired images must be evicted")
        cache.insert(image, for: entry("d"), now: 20)
        cache.clear()
        precondition(cache.bytes == 0)
        let countCache = StatusImageCache()
        for i in 0..<129 { countCache.insert(image, for: entry(String(i)), now: 0) }
        precondition(countCache.image(for: entry("0"), now: 1) == nil)
        precondition(countCache.image(for: entry("1"), now: 1) != nil && countCache.bytes == 128 * 1024)
        let parent = CGContext(data: nil, width: 1024, height: 64, bitsPerComponent: 8,
                               bytesPerRow: 4096, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let cropped = parent.cropping(to: CGRect(x: 0, y: 0, width: 16, height: 16))!
        cache.insert(cropped, for: entry("crop"), now: 30)
        precondition(cache.bytes == 1024 && cache.image(for: entry("crop"), now: 31) != nil,
                     "Crop must own only its compact pixels regardless of parent stride")
        print("Image identity/reconciliation, expiry, count and compact byte-budget checks passed")
    }
}
