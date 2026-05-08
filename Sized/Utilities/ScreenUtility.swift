import AppKit

enum ScreenUtility {
    static func screen(containing point: CGPoint) -> NSScreen {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens.first!
    }

    static func centerPoint(in screen: NSScreen) -> CGPoint {
        CGPoint(x: screen.frame.midX, y: screen.frame.midY)
    }

    static func screen(containing frame: CGRect) -> NSScreen {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return screen(containing: center)
    }

    static func nextScreen(after screen: NSScreen) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1, let index = screens.firstIndex(of: screen) else { return nil }
        return screens[(index + 1) % screens.count]
    }

    static func previousScreen(before screen: NSScreen) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1, let index = screens.firstIndex(of: screen) else { return nil }
        return screens[(index - 1 + screens.count) % screens.count]
    }

    static func directionalScreen(from screen: NSScreen, dx: CGFloat, dy: CGFloat) -> NSScreen? {
        let origin = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
        return NSScreen.screens
            .filter { $0 != screen }
            .map { candidate -> (screen: NSScreen, score: CGFloat)? in
                let vector = CGPoint(x: candidate.frame.midX - origin.x, y: candidate.frame.midY - origin.y)
                let dot = vector.x * dx + vector.y * dy
                guard dot > 0 else { return nil }
                let crossPenalty = abs(vector.x * dy - vector.y * dx)
                return (candidate, dot - crossPenalty * 0.25)
            }
            .compactMap { $0 }
            .max { $0.score < $1.score }?
            .screen
    }
}
