import AppKit
import ApplicationServices
import OSLog

enum WindowActionPreviewStyle {
    case standard
    case danger
}

struct WindowActionPreview {
    var frame: CGRect
    var style: WindowActionPreviewStyle
}

@MainActor
final class WindowActionEngine {
    private struct ActiveResizeAnimation {
        let window: AXUIElement
        let animation: WindowTransformAnimation
    }

    static let shared = WindowActionEngine()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Sized", category: "WindowResize")
    private var resizeContext = ResizeContext()
    private var activeResizeAnimations: [ActiveResizeAnimation] = []

    private init() {}

    func hasTargetWindow(_ targetWindow: FocusedWindow?) -> Bool {
        targetWindow != nil
    }

    func targetFrame(for action: RadialMenuAction, targetWindow: FocusedWindow?) -> CGRect? {
        guard let targetWindow else { return nil }
        return targetFrame(for: action, focusedWindow: targetWindow)
    }

    func preview(for action: RadialMenuAction, targetWindow: FocusedWindow?) -> WindowActionPreview? {
        guard let targetWindow else { return nil }

        if action.isDestructiveCommand {
            return WindowActionPreview(frame: targetWindow.frame, style: .danger)
        }

        guard let frame = targetFrame(for: action, focusedWindow: targetWindow) else { return nil }
        return WindowActionPreview(frame: frame, style: .standard)
    }

    @discardableResult
    func perform(_ action: RadialMenuAction, targetWindow: FocusedWindow?) -> Bool {
        AccessibilityManager.shared.refresh()
        guard AccessibilityManager.shared.isTrusted else {
            AccessibilityManager.shared.requestAccess()
            return false
        }

        guard let targetWindow else { return false }
        cancelResizeAnimation(for: targetWindow.windowElement)
        let currentFrame = WindowUtility.frame(of: targetWindow.windowElement) ?? targetWindow.frame
        let currentWindow = FocusedWindow(
            application: targetWindow.application,
            appElement: targetWindow.appElement,
            windowElement: targetWindow.windowElement,
            frame: currentFrame
        )

        switch action.mode {
        case .noAction:
            return true
        case .windowCommand:
            return performWindowCommand(action.windowCommand, focusedWindow: currentWindow, currentFrame: currentFrame)
        case .screenLayout where action.screenLayout == .systemFullScreen:
            resizeContext.remember(pid: targetWindow.application.processIdentifier, frame: currentFrame)
            return WindowUtility.performFullScreen(for: targetWindow.windowElement)
        case .fixedSize, .screenLayout, .relativeScale:
            guard let targetFrame = targetFrame(for: action, focusedWindow: currentWindow) else { return false }
            resizeContext.remember(pid: targetWindow.application.processIdentifier, frame: currentFrame)
            let allowConstrainedResult = action.mode == .relativeScale && action.scaleDirection == .shrink
            return applyFrame(
                targetFrame.integral,
                from: currentFrame,
                to: targetWindow.windowElement,
                anchor: frameAnchor(for: action),
                allowConstrainedResult: allowConstrainedResult
            )
        }
    }

    private func targetFrame(for action: RadialMenuAction, focusedWindow: FocusedWindow) -> CGRect? {
        let current = focusedWindow.frame
        let screen = WindowUtility.screen(forAXFrame: current)
        let visible = WindowUtility.visibleAXFrame(for: screen)

        switch action.mode {
        case .noAction:
            return nil
        case .windowCommand:
            switch action.windowCommand {
            case .restoreInitial:
                return resizeContext.initialFrame
            case .undo:
                return resizeContext.lastFrame
            case .minimize, .closeWindow, .quitApplication:
                return nil
            }
        case .fixedSize:
            if action.fixedSizeKind == .custom {
                return frame(byResizing: current, to: CGSize(width: action.customSize.width, height: action.customSize.height), within: visible)
            }
            guard let preset = action.fixedSizeKind.fixedSize else { return nil }
            return frame(byResizing: current, to: CGSize(width: preset.width, height: preset.height), within: visible)
        case .screenLayout:
            return frame(for: action.screenLayout, within: visible)
        case .relativeScale:
            return frame(byScaling: current, action: action, within: visible)
        }
    }

    private func performWindowCommand(_ command: WindowCommandAction, focusedWindow: FocusedWindow, currentFrame: CGRect) -> Bool {
        switch command {
        case .minimize:
            return WindowUtility.setMinimized(true, for: focusedWindow.windowElement)
        case .closeWindow:
            return WindowUtility.performClose(for: focusedWindow.windowElement)
        case .quitApplication:
            return focusedWindow.application.terminate()
        case .restoreInitial:
            guard let initialFrame = resizeContext.initialFrame else { return false }
            resizeContext.lastFrame = currentFrame
            return applyFrame(initialFrame, from: currentFrame, to: focusedWindow.windowElement)
        case .undo:
            guard let lastFrame = resizeContext.lastFrame else { return false }
            resizeContext.lastFrame = currentFrame
            return applyFrame(lastFrame, from: currentFrame, to: focusedWindow.windowElement)
        }
    }

    private func frame(for layout: ScreenLayoutAction, within visible: CGRect) -> CGRect? {
        switch layout {
        case .fillVisible:
            return visible
        case .systemFullScreen:
            return nil
        case .leftHalf:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .rightHalf:
            return CGRect(x: visible.midX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .leftThird:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width / 3, height: visible.height)
        case .centerThird:
            return CGRect(x: visible.minX + visible.width / 3, y: visible.minY, width: visible.width / 3, height: visible.height)
        case .rightThird:
            return CGRect(x: visible.minX + visible.width * 2 / 3, y: visible.minY, width: visible.width / 3, height: visible.height)
        case .topLeftQuarter:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height / 2)
        case .topRightQuarter:
            return CGRect(x: visible.midX, y: visible.minY, width: visible.width / 2, height: visible.height / 2)
        case .bottomLeftQuarter:
            return CGRect(x: visible.minX, y: visible.midY, width: visible.width / 2, height: visible.height / 2)
        case .bottomRightQuarter:
            return CGRect(x: visible.midX, y: visible.midY, width: visible.width / 2, height: visible.height / 2)
        }
    }

    private func frame(byScaling current: CGRect, action: RadialMenuAction, within visible: CGRect) -> CGRect {
        let percent = RadialMenuAction.clampedScalePercent(action.scalePercent, direction: action.scaleDirection)
        let factor: CGFloat
        switch action.scaleDirection {
        case .enlarge:
            factor = 1 + CGFloat(percent / 100)
        case .shrink:
            factor = 1 - CGFloat(percent / 100)
        }

        let requestedSize = CGSize(width: current.width * factor, height: current.height * factor)

        if action.scaleDirection == .enlarge,
           (requestedSize.width > visible.width || requestedSize.height > visible.height) {
            return visible
        }

        let minimumSize = action.scaleDirection == .shrink ? CGSize(width: 1, height: 1) : CGSize(width: 180, height: 120)
        let size = CGSize(
            width: min(max(minimumSize.width, requestedSize.width), visible.width),
            height: min(max(minimumSize.height, requestedSize.height), visible.height)
        )

        let origin: CGPoint
        switch action.scaleAnchor {
        case .topLeft:
            origin = current.origin
        case .topRight:
            origin = CGPoint(x: current.maxX - size.width, y: current.minY)
        case .center:
            origin = CGPoint(x: current.midX - size.width / 2, y: current.midY - size.height / 2)
        }

        return clamp(CGRect(origin: origin, size: size), within: visible)
    }

    private func frame(byResizing current: CGRect, to requestedSize: CGSize, within visible: CGRect) -> CGRect {
        let size = CGSize(
            width: min(max(180, requestedSize.width), visible.width),
            height: min(max(120, requestedSize.height), visible.height)
        )

        let origin: CGPoint
        switch SettingsStore.shared.behavior.resizeAnchor {
        case .currentCenter:
            origin = CGPoint(
                x: current.midX - size.width / 2,
                y: current.midY - size.height / 2
            )
        case .topLeft:
            origin = current.origin
        }

        return clamp(CGRect(origin: origin, size: size), within: visible)
    }

    private func clamp(_ frame: CGRect, within visible: CGRect) -> CGRect {
        var result = frame

        if result.minX < visible.minX {
            result.origin.x = visible.minX
        }
        if result.maxX > visible.maxX {
            result.origin.x = visible.maxX - result.width
        }
        if result.minY < visible.minY {
            result.origin.y = visible.minY
        }
        if result.maxY > visible.maxY {
            result.origin.y = visible.maxY - result.height
        }

        return result
    }

    private func frameAnchor(for action: RadialMenuAction) -> CGPoint? {
        switch action.mode {
        case .fixedSize:
            return SettingsStore.shared.behavior.resizeAnchor == .currentCenter
                ? CGPoint(x: 0.5, y: 0.5)
                : .zero
        case .screenLayout:
            return nil
        case .relativeScale:
            switch action.scaleAnchor {
            case .topLeft: return .zero
            case .topRight: return CGPoint(x: 1, y: 0)
            case .center: return CGPoint(x: 0.5, y: 0.5)
            }
        case .windowCommand, .noAction:
            return nil
        }
    }

    private func applyFrame(
        _ targetFrame: CGRect,
        from currentFrame: CGRect,
        to window: AXUIElement,
        anchor: CGPoint? = nil,
        allowConstrainedResult: Bool = false
    ) -> Bool {
        let targetFrame = targetFrame.integral

        guard SettingsStore.shared.behavior.resizeAnimation,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              !WindowUtility.hasEnhancedUserInterface(window),
              !framesAreClose(currentFrame, targetFrame)
        else {
            let result = WindowUtility.setFrameDetailed(targetFrame, for: window)
            log(result, phase: "direct")
            return result.isSuccessful || (allowConstrainedResult && result.apiSucceeded)
        }

        let startFrame = (WindowUtility.frame(of: window) ?? currentFrame).integral
        let screen = WindowUtility.screen(forAXFrame: targetFrame)
        let sourceScreen = WindowUtility.screen(forAXFrame: startFrame)
        let bounds = sourceScreen == screen ? WindowUtility.visibleAXFrame(for: screen) : .zero
        let animation = WindowTransformAnimation(
            from: startFrame,
            to: targetFrame,
            within: bounds,
            anchor: anchor,
            window: window,
            duration: SettingsStore.shared.behavior.resizeAnimationDuration
        ) { [weak self] animationID, cancelled in
            guard let self,
                  let index = self.activeResizeAnimations.firstIndex(where: { $0.animation.id == animationID })
            else { return }
            self.activeResizeAnimations.remove(at: index)
            guard !cancelled, SettingsStore.shared.behavior.resizeDiagnostics else { return }
            let result = WindowUtility.inspectFrame(targetFrame, for: window)
            self.log(result, phase: "animated-final")
        }
        activeResizeAnimations.append(ActiveResizeAnimation(window: window, animation: animation))
        animation.start()
        return true
    }

    private func cancelResizeAnimation(for window: AXUIElement) {
        guard let index = activeResizeAnimations.firstIndex(where: { CFEqual($0.window, window) }) else { return }
        let animation = activeResizeAnimations.remove(at: index).animation
        animation.cancel()
    }

    private func framesAreClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 1 &&
            abs(lhs.minY - rhs.minY) < 1 &&
            abs(lhs.width - rhs.width) < 1 &&
            abs(lhs.height - rhs.height) < 1
    }

    private func log(_ result: WindowResizeResult, phase: String) {
        guard SettingsStore.shared.behavior.resizeDiagnostics || !result.isSuccessful else { return }
        if result.isSuccessful {
            logger.info("Resize \(phase, privacy: .public) succeeded: \(result.diagnosticDescription, privacy: .public)")
        } else {
            logger.error("Resize \(phase, privacy: .public) failed: \(result.diagnosticDescription, privacy: .public)")
        }
    }
}
