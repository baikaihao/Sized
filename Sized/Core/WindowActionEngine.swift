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
    static let shared = WindowActionEngine()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Sized", category: "WindowResize")
    private var resizeContext = ResizeContext()
    private var resizeAnimationTask: Task<Void, Never>?
    private let resizeAnimationFrameRate: Double = 60

    private init() {}

    func hasFocusedWindow() -> Bool {
        WindowUtility.focusedWindow() != nil
    }

    func targetFrame(for action: RadialMenuAction) -> CGRect? {
        guard let focusedWindow = WindowUtility.focusedWindow() else { return nil }
        return targetFrame(for: action, focusedWindow: focusedWindow)
    }

    func preview(for action: RadialMenuAction) -> WindowActionPreview? {
        guard let focusedWindow = WindowUtility.focusedWindow() else { return nil }

        if action.isDestructiveCommand {
            return WindowActionPreview(frame: focusedWindow.frame, style: .danger)
        }

        guard let frame = targetFrame(for: action, focusedWindow: focusedWindow) else { return nil }
        return WindowActionPreview(frame: frame, style: .standard)
    }

    @discardableResult
    func perform(_ action: RadialMenuAction) -> Bool {
        AccessibilityManager.shared.refresh()
        guard AccessibilityManager.shared.isTrusted else {
            AccessibilityManager.shared.requestAccess()
            return false
        }

        guard let focusedWindow = WindowUtility.focusedWindow() else { return false }
        let currentFrame = focusedWindow.frame

        switch action.mode {
        case .noAction:
            return true
        case .windowCommand:
            return performWindowCommand(action.windowCommand, focusedWindow: focusedWindow, currentFrame: currentFrame)
        case .screenLayout where action.screenLayout == .systemFullScreen:
            resizeContext.remember(pid: focusedWindow.application.processIdentifier, frame: currentFrame)
            return WindowUtility.performFullScreen(for: focusedWindow.windowElement)
        case .fixedSize, .screenLayout, .relativeScale:
            guard let targetFrame = targetFrame(for: action, focusedWindow: focusedWindow) else { return false }
            resizeContext.remember(pid: focusedWindow.application.processIdentifier, frame: currentFrame)
            let allowConstrainedResult = action.mode == .relativeScale && action.scaleDirection == .shrink
            return applyFrame(targetFrame.integral, from: currentFrame, to: focusedWindow.windowElement, allowConstrainedResult: allowConstrainedResult)
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

    private func applyFrame(_ targetFrame: CGRect, from currentFrame: CGRect, to window: AXUIElement, allowConstrainedResult: Bool = false) -> Bool {
        let targetFrame = targetFrame.integral
        resizeAnimationTask?.cancel()

        guard SettingsStore.shared.behavior.resizeAnimation,
              !framesAreClose(currentFrame, targetFrame)
        else {
            let result = WindowUtility.setFrameDetailed(targetFrame, for: window)
            log(result, phase: "direct")
            return result.isSuccessful || (allowConstrainedResult && result.apiSucceeded)
        }

        let startFrame = currentFrame.integral
        let initialResult = WindowUtility.setFrameDetailed(startFrame, for: window)
        guard initialResult.isSuccessful else {
            log(initialResult, phase: "animated-start")
            return false
        }

        resizeAnimationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.animateFrameChange(from: startFrame, to: targetFrame, for: window)
        }
        return true
    }

    private func animateFrameChange(from startFrame: CGRect, to targetFrame: CGRect, for window: AXUIElement) async {
        let duration = SettingsStore.shared.behavior.resizeAnimationDuration
        let frameCount = max(1, Int(duration * resizeAnimationFrameRate))
        let frameDelay = UInt64(1_000_000_000 / resizeAnimationFrameRate)

        for frameIndex in 1...frameCount {
            if Task.isCancelled { return }
            let progress = CGFloat(frameIndex) / CGFloat(frameCount)
            let easedProgress = easeOutCubic(progress)
            let frame = interpolate(from: startFrame, to: targetFrame, progress: easedProgress).integral
            _ = WindowUtility.setFrameDetailed(frame, for: window)
            try? await Task.sleep(nanoseconds: frameDelay)
        }

        if !Task.isCancelled {
            let result = WindowUtility.setFrameDetailed(targetFrame.integral, for: window)
            log(result, phase: "animated-final")
        }
    }

    private func interpolate(from startFrame: CGRect, to targetFrame: CGRect, progress: CGFloat) -> CGRect {
        CGRect(
            x: startFrame.minX + (targetFrame.minX - startFrame.minX) * progress,
            y: startFrame.minY + (targetFrame.minY - startFrame.minY) * progress,
            width: startFrame.width + (targetFrame.width - startFrame.width) * progress,
            height: startFrame.height + (targetFrame.height - startFrame.height) * progress
        )
    }

    private func easeOutCubic(_ progress: CGFloat) -> CGFloat {
        1 - pow(1 - progress, 3)
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
