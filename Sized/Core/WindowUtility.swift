import AppKit
import ApplicationServices

struct FocusedWindow {
    let application: NSRunningApplication
    let appElement: AXUIElement
    let windowElement: AXUIElement
    let frame: CGRect
}

enum WindowUtility {
    static func focusedWindow() -> FocusedWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedValue)

        let windowElement: AXUIElement?
        if focusedResult == .success, let focusedValue {
            windowElement = (focusedValue as! AXUIElement)
        } else {
            windowElement = firstWindow(in: appElement)
        }

        guard let windowElement, let frame = frame(of: windowElement) else { return nil }
        return FocusedWindow(application: app, appElement: appElement, windowElement: windowElement, frame: frame)
    }

    static func firstWindow(in appElement: AXUIElement) -> AXUIElement? {
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success else { return nil }
        guard let windows = windowsValue as? [AXUIElement] else { return nil }
        return windows.first
    }

    static func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute, window: window),
              let size = sizeAttribute(kAXSizeAttribute, window: window)
        else { return nil }

        return CGRect(origin: position, size: size)
    }

    static func setFrame(_ frame: CGRect, for window: AXUIElement) -> Bool {
        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return false }

        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        return positionResult == .success && sizeResult == .success
    }

    static func setMinimized(_ minimized: Bool, for window: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, minimized as CFBoolean) == .success
    }

    static func performZoom(for window: AXUIElement) -> Bool {
        var zoomButtonValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXZoomButtonAttribute as CFString, &zoomButtonValue) == .success,
              let zoomButtonValue,
              CFGetTypeID(zoomButtonValue) == AXUIElementGetTypeID()
        else { return false }

        let zoomButton = zoomButtonValue as! AXUIElement
        return AXUIElementPerformAction(zoomButton, kAXPressAction as CFString) == .success
    }

    static func visibleAXFrame(for screen: NSScreen) -> CGRect {
        appKitRectToAX(screen.visibleFrame)
    }

    static func appKitRectToAX(_ rect: CGRect) -> CGRect {
        let globalMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? rect.maxY
        return CGRect(x: rect.minX, y: globalMaxY - rect.maxY, width: rect.width, height: rect.height)
    }

    static func axRectToAppKit(_ rect: CGRect) -> CGRect {
        let globalMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? rect.maxY
        return CGRect(x: rect.minX, y: globalMaxY - rect.maxY, width: rect.width, height: rect.height)
    }

    static func screen(forAXFrame frame: CGRect) -> NSScreen {
        let appKitFrame = axRectToAppKit(frame)
        return ScreenUtility.screen(containing: appKitFrame)
    }

    private static func pointAttribute(_ attribute: String, window: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }

        let axValue = value as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func sizeAttribute(_ attribute: String, window: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }

        let axValue = value as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }
}
