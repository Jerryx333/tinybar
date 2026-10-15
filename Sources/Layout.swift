import AppKit

// Pure geometry shared by the app and the headless layout tests.
enum BarLayout {
    static let dividerWidth: CGFloat = 14
    static let controlWidth: CGFloat = 24
    // AppKit clamps very long status items on the tested OS. Always verify the resulting frame.
    static let maximumWidth: CGFloat = 5000

    static func hidingWidth(screens: [NSRect]) -> CGFloat? {
        guard !screens.isEmpty, screens.allSatisfy({ $0.width > 0 && $0.width.isFinite }) else { return nil }
        let span = screens.map(\.maxX).max()! - screens.map(\.minX).min()!
        guard span.isFinite, span + 512 <= maximumWidth else { return nil }
        return max(4000, span + 512)
    }

    static func controlScreen(_ control: NSRect, screens: [NSRect]) -> Int? {
        guard control.width > 0, control.height > 0 else { return nil }
        return screens.firstIndex { screen in
            control.minX >= screen.minX && control.maxX <= screen.maxX &&
            abs(control.maxY - screen.maxY) <= 2 && control.height <= 64
        }
    }

    static func ordered(control: NSRect, divider: NSRect) -> Bool {
        divider.width > 0 && abs(control.maxY - divider.maxY) <= 2 &&
        divider.maxX <= control.minX + 1
    }

    static func displaced(divider: NSRect, screens: [NSRect]) -> Bool {
        guard let left = screens.map(\.minX).min() else { return false }
        return divider.minX < left - 32
    }
}
