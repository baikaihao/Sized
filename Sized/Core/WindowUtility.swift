import AppKit
import ApplicationServices

struct FocusedWindow {
    let application: NSRunningApplication
    let appElement: AXUIElement
    let windowElement: AXUIElement
    let frame: CGRect
}

struct WindowResizeResult {
    let requestedFrame: CGRect
    let initialFrame: CGRect?
    let actualFrame: CGRect?
    let role: String?
    let subrole: String?
    let title: String?
    let positionSettable: Bool?
    let sizeSettable: Bool?
    let positionResult: AXError
    let sizeResult: AXError
    let didCreateAXValues: Bool

    var apiSucceeded: Bool {
        didCreateAXValues && positionResult == .success && sizeResult == .success
    }

    var reachedTarget: Bool {
        guard let actualFrame else { return false }
        return Self.framesAreClose(actualFrame, requestedFrame)
    }

    var isSuccessful: Bool {
        reachedTarget
    }

    var diagnosticDescription: String {
        [
            "role=\(role ?? "unknown")",
            "subrole=\(subrole ?? "unknown")",
            "title=\(title ?? "untitled")",
            "positionSettable=\(Self.optionalBoolDescription(positionSettable))",
            "sizeSettable=\(Self.optionalBoolDescription(sizeSettable))",
            "positionResult=\(positionResult.diagnosticDescription)",
            "sizeResult=\(sizeResult.diagnosticDescription)",
            "requested=\(Self.frameDescription(requestedFrame))",
            "before=\(Self.frameDescription(initialFrame))",
            "actual=\(Self.frameDescription(actualFrame))",
            "apiSucceeded=\(apiSucceeded)",
            "reachedTarget=\(reachedTarget)"
        ].joined(separator: " ")
    }

    static func frameDescription(_ frame: CGRect?) -> String {
        guard let frame else { return "nil" }
        return "x:\(Int(frame.minX)) y:\(Int(frame.minY)) w:\(Int(frame.width)) h:\(Int(frame.height))"
    }

    private static func optionalBoolDescription(_ value: Bool?) -> String {
        guard let value else { return "unknown" }
        return value ? "true" : "false"
    }

    private static func framesAreClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 2 &&
            abs(lhs.minY - rhs.minY) < 2 &&
            abs(lhs.width - rhs.width) < 2 &&
            abs(lhs.height - rhs.height) < 2
    }
}

enum WindowUtility {
    static func focusedWindow() -> FocusedWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedValue)

        let focusedElement: AXUIElement?
        if focusedResult == .success,
           let focusedValue,
           CFGetTypeID(focusedValue) == AXUIElementGetTypeID() {
            focusedElement = (focusedValue as! AXUIElement)
        } else {
            focusedElement = nil
        }

        let windowElement = focusedElement.flatMap { isUsableWindowElement($0) ? $0 : nil } ?? firstWindow(in: appElement)

        guard let windowElement, let frame = frame(of: windowElement) else { return nil }
        return FocusedWindow(application: app, appElement: appElement, windowElement: windowElement, frame: frame)
    }

    static func firstWindow(in appElement: AXUIElement) -> AXUIElement? {
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success else { return nil }
        guard let windows = windowsValue as? [AXUIElement] else { return nil }
        let framedWindows = windows.filter { frame(of: $0) != nil }
        return framedWindows.first { isStandardWindowElement($0) } ??
            framedWindows.first { isWindowElement($0) } ??
            framedWindows.first ??
            windows.first
    }

    static func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute, window: window),
              let size = sizeAttribute(kAXSizeAttribute, window: window)
        else { return nil }

        return CGRect(origin: position, size: size)
    }

    static func setFrame(_ frame: CGRect, for window: AXUIElement) -> Bool {
        setFrameDetailed(frame, for: window).isSuccessful
    }

    static func setFrameDetailed(_ frame: CGRect, for window: AXUIElement) -> WindowResizeResult {
        let requestedFrame = frame.integral
        let initialFrame = self.frame(of: window)
        let role = stringAttribute(kAXRoleAttribute, window: window)
        let subrole = stringAttribute(kAXSubroleAttribute, window: window)
        let title = stringAttribute(kAXTitleAttribute, window: window)
        let positionSettable = isAttributeSettable(kAXPositionAttribute, window: window)
        let sizeSettable = isAttributeSettable(kAXSizeAttribute, window: window)

        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            return WindowResizeResult(
                requestedFrame: requestedFrame,
                initialFrame: initialFrame,
                actualFrame: self.frame(of: window),
                role: role,
                subrole: subrole,
                title: title,
                positionSettable: positionSettable,
                sizeSettable: sizeSettable,
                positionResult: .failure,
                sizeResult: .failure,
                didCreateAXValues: false
            )
        }

        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)

        return WindowResizeResult(
            requestedFrame: requestedFrame,
            initialFrame: initialFrame,
            actualFrame: self.frame(of: window),
            role: role,
            subrole: subrole,
            title: title,
            positionSettable: positionSettable,
            sizeSettable: sizeSettable,
            positionResult: positionResult,
            sizeResult: sizeResult,
            didCreateAXValues: true
        )
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

    private static func stringAttribute(_ attribute: String, window: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func isAttributeSettable(_ attribute: String, window: AXUIElement) -> Bool? {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(window, attribute as CFString, &settable)
        guard result == .success else { return nil }
        return settable.boolValue
    }

    private static func isUsableWindowElement(_ element: AXUIElement) -> Bool {
        guard frame(of: element) != nil else { return false }
        let role = stringAttribute(kAXRoleAttribute, window: element)
        return role == nil || role == "AXWindow"
    }

    private static func isWindowElement(_ element: AXUIElement) -> Bool {
        stringAttribute(kAXRoleAttribute, window: element) == "AXWindow"
    }

    private static func isStandardWindowElement(_ element: AXUIElement) -> Bool {
        isWindowElement(element) && stringAttribute(kAXSubroleAttribute, window: element) == "AXStandardWindow"
    }
}

private extension AXError {
    var diagnosticDescription: String {
        switch self {
        case .success: "success"
        case .failure: "failure"
        case .illegalArgument: "illegalArgument"
        case .invalidUIElement: "invalidUIElement"
        case .invalidUIElementObserver: "invalidUIElementObserver"
        case .cannotComplete: "cannotComplete"
        case .attributeUnsupported: "attributeUnsupported"
        case .actionUnsupported: "actionUnsupported"
        case .notificationUnsupported: "notificationUnsupported"
        case .notImplemented: "notImplemented"
        case .notificationAlreadyRegistered: "notificationAlreadyRegistered"
        case .notificationNotRegistered: "notificationNotRegistered"
        case .apiDisabled: "apiDisabled"
        case .noValue: "noValue"
        case .parameterizedAttributeUnsupported: "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: "notEnoughPrecision"
        @unknown default: "unknown(\(rawValue))"
        }
    }
}
