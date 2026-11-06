// Compiles the production animation and preview sources with a deterministic AX
// stand-in. No user windows or Accessibility settings are changed.
import AppKit
import ApplicationServices
import Combine
import SwiftUI

@MainActor
enum WindowUtility {
    static var actual = CGRect.zero
    static var minimum = CGSize.zero
    static var fixedWidth: CGFloat?
    static var aspectRatio: CGFloat?
    static var resizable = true
    static var valid = true
    static var writes = 0
    static var sizeWrites = 0
    static var order: [String] = []
    static var visible = CGRect.zero
    static var enhancedUserInterface = false
    static var enhancedUserInterfaceLog: [Bool] = []
    /// An app in the middle of its own layout pass answers the AX calls but ignores them.
    static var dropsFirstAttempt = false
    static var attempt = 0

    static func reset(_ frame: CGRect) {
        actual = frame
        minimum = .zero
        fixedWidth = nil
        aspectRatio = nil
        resizable = true
        valid = true
        writes = 0
        sizeWrites = 0
        order = []
        visible = CGRect.zero
        enhancedUserInterface = false
        enhancedUserInterfaceLog = []
        dropsFirstAttempt = false
        attempt = 0
    }

    static func frame(of window: AXUIElement) -> CGRect? {
        attempt += 1
        return valid ? actual : nil
    }
    static func isResizable(_ window: AXUIElement) -> Bool { resizable }
    static func screen(forAXFrame frame: CGRect) -> NSScreen { NSScreen.screens[0] }
    static func visibleAXFrame(for screen: NSScreen) -> CGRect { visible }
    static func hasEnhancedUserInterface(_ window: AXUIElement) -> Bool { enhancedUserInterface }
    static func setEnhancedUserInterface(_ enabled: Bool, for window: AXUIElement) {
        enhancedUserInterface = enabled
        enhancedUserInterfaceLog.append(enabled)
    }

    struct ResizeMetadata {
        let role: String?
        let subrole: String?
        let title: String?
        let positionSettable: Bool?
        let sizeSettable: Bool?
    }

    static func resizeMetadata(for window: AXUIElement) -> ResizeMetadata {
        ResizeMetadata(
            role: "AXWindow",
            subrole: "AXStandardWindow",
            title: "Test Window",
            positionSettable: true,
            sizeSettable: resizable
        )
    }

    private static func droppedWrite() -> Bool { dropsFirstAttempt && attempt <= 1 }

    static func axRectToAppKit(_ frame: CGRect) -> CGRect {
        CGRect(x: frame.minX, y: NSScreen.screens[0].frame.maxY - frame.maxY, width: frame.width, height: frame.height)
    }
    static func setPositionFast(_ position: CGPoint, for window: AXUIElement) -> AXError {
        writes += 1
        order.append("position")
        guard !droppedWrite() else { return .success }
        actual.origin = position
        return .success
    }
    static func setSizeFast(_ size: CGSize, for window: AXUIElement) -> AXError {
        writes += 1
        sizeWrites += 1
        order.append("size")
        guard !droppedWrite() else { return .success }
        guard resizable else { return .attributeUnsupported }
        var size = CGSize(width: max(minimum.width, size.width), height: max(minimum.height, size.height))
        if let fixedWidth { size.width = fixedWidth }
        if let aspectRatio {
            size = size.width / size.height > aspectRatio
                ? CGSize(width: size.height * aspectRatio, height: size.height)
                : CGSize(width: size.width, height: size.width / aspectRatio)
        }
        actual.size = size
        return .success
    }
}

extension AXError {
    var diagnosticDescription: String { self == .success ? "success" : "failure" }
}

// Only the settings consumed by the production preview are needed here.
struct BehaviorSettings {
    var showPreview = true
    var previewPadding = 0.0
    var previewAnimationSpeed = 0.05
    var previewBackgroundColorHex = "#0A84FF"
    var previewBorderColorHex = "#3A79FF"
    var previewCornerRadius = 22.0
    var previewBorderWidth = 2.0
    static let `default` = Self()
}
@MainActor
final class SettingsStore {
    static let shared = SettingsStore()
    var behavior = BehaviorSettings.default
}
enum WindowActionPreviewStyle { case standard, danger }

@main
struct WindowAnimationChecks {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let window = AXUIElementCreateSystemWide()
        let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let original = CGRect(x: 200, y: 150, width: 600, height: 400)
        var passed = 0

        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            passed += 1
        }
        func make(_ target: CGRect, anchor: CGPoint? = nil, bounded: Bool = true, completion: @escaping (UUID, Bool) -> Void = { _, _ in }) -> WindowTransformAnimation {
            WindowTransformAnimation(from: WindowUtility.actual, to: target, within: bounded ? bounds : .zero, anchor: anchor, window: window, duration: 0.3, completion: completion)
        }
        func drive(_ animation: WindowTransformAnimation) {
            for step in 0...60 { animation.currentProgress = Float(step) / 60 }
        }
        func pump(_ duration: TimeInterval) {
            let deadline = Date().addingTimeInterval(duration)
            while Date() < deadline { RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.005))) }
        }

        WindowUtility.reset(original)
        let target = CGRect(x: 720, y: 0, width: 720, height: 900)
        var completions: [Bool] = []
        let full = make(target) { _, cancelled in completions.append(cancelled) }
        check(full.animationBlockingMode == .nonblocking, "Animation must not block input")
        check(full.frameRate >= 60, "Use display refresh rate")
        full.currentProgress = 0.5
        let eased = CGFloat(1 - pow(1 - full.currentValue, 3))
        check(abs(WindowUtility.actual.minX - round(original.minX + eased * (target.minX - original.minX))) < 1, "Match Loop's NSAnimation + cubic easing")
        drive(full)
        check(WindowUtility.actual == target, "Reach the exact target")
        check(completions == [false], "Complete exactly once")
        full.cancel()
        full.stop()
        check(completions == [false], "Completed animation cannot complete again")

        WindowUtility.reset(original)
        completions = []
        let cancelled = make(target) { _, wasCancelled in completions.append(wasCancelled) }
        cancelled.currentProgress = 0.25
        let interruptedFrame = WindowUtility.actual
        cancelled.cancel()
        check(completions == [true], "Cancellation must complete synchronously")
        let writesAtCancel = WindowUtility.writes
        cancelled.currentProgress = 1
        cancelled.start()
        check(WindowUtility.writes == writesAtCancel, "Cancelled animation cannot write or restart")
        let reversed = make(CGRect(x: 0, y: 0, width: 720, height: 900))
        reversed.currentProgress = 0
        check(WindowUtility.actual == interruptedFrame, "Retarget from the visible frame without a jump")
        drive(reversed)
        check(WindowUtility.actual.minX == 0, "Reversal reaches its destination")

        WindowUtility.reset(original)
        WindowUtility.minimum = CGSize(width: 500, height: 300)
        drive(make(CGRect(x: 1000, y: 600, width: 200, height: 100), anchor: CGPoint(x: 1, y: 0)))
        check(WindowUtility.actual == CGRect(x: 700, y: 600, width: 500, height: 300), "Minimum-size window preserves the top-right anchor")

        WindowUtility.reset(original)
        WindowUtility.fixedWidth = original.width
        drive(make(target))
        check(WindowUtility.actual == CGRect(x: 840, y: 0, width: 600, height: 900), "Fixed-width window remains aligned to right screen edge")

        WindowUtility.reset(original)
        WindowUtility.aspectRatio = 1.5
        drive(make(target))
        check(abs(WindowUtility.actual.width / WindowUtility.actual.height - 1.5) < 0.001, "Preserve a fixed aspect ratio")
        check(WindowUtility.actual.maxX == bounds.maxX, "Aspect-constrained window keeps the target edge")

        WindowUtility.reset(original)
        drive(make(CGRect(x: 40, y: 50, width: 600, height: 400)))
        check(WindowUtility.sizeWrites == 0, "A position-only animation does not reflow window content")

        WindowUtility.reset(original)
        WindowUtility.resizable = false
        drive(make(CGRect(x: 40, y: 50, width: 600, height: 400)))
        check(WindowUtility.sizeWrites == 0, "Do not send size writes to a nonresizable window")
        check(WindowUtility.actual.origin == CGPoint(x: 40, y: 50), "Nonresizable windows can still move")

        WindowUtility.reset(original)
        let otherScreen = CGRect(x: -1200, y: -600, width: 800, height: 600)
        drive(make(otherScreen, bounded: false))
        check(WindowUtility.actual == otherScreen, "Cross-screen motion is not clamped to the source screen")

        WindowUtility.reset(original)
        completions = []
        let invalid = make(target) { _, wasCancelled in completions.append(wasCancelled) }
        WindowUtility.valid = false
        invalid.currentProgress = 0.2
        check(completions == [true], "A disappearing window terminates its animation")

        // Exercise the actual AppKit timer and run loop, not just sampled values.
        WindowUtility.reset(original)
        completions = []
        let live = make(target) { _, wasCancelled in completions.append(wasCancelled) }
        live.start()
        pump(0.45)
        check(WindowUtility.actual == target && completions == [false], "Nonblocking NSAnimation runs to completion on the live run loop")

        // MARK: - Loop's snap path: one write, one read-back, no interpolation.

        func snap(
            _ frame: CGRect,
            to target: CGRect,
            bounds: CGRect,
            sizeFirst: Bool = false,
            resizable: Bool = true,
            enhancedUserInterface: Bool = false,
            configure: (() -> Void)? = nil
        ) -> WindowResizeResult {
            WindowUtility.reset(frame)
            WindowUtility.visible = bounds
            WindowUtility.resizable = resizable
            WindowUtility.enhancedUserInterface = enhancedUserInterface
            configure?()
            return WindowEngine.resize(
                window: window,
                to: target,
                bounds: bounds,
                sizeFirst: sizeFirst,
                properties: .init(isResizable: resizable, enhancedUserInterface: enhancedUserInterface),
                diagnostics: false
            )
        }

        check(!WindowEngine.shouldAnimate(explicitlyEnabled: false, properties: .init(isResizable: true, enhancedUserInterface: false)), "Animation stays off unless it is asked for")
        check(!WindowEngine.shouldAnimate(explicitlyEnabled: true, properties: .init(isResizable: true, enhancedUserInterface: true)), "Enhanced UI apps never interpolate")

        var result = snap(original, to: target, bounds: bounds)
        check(WindowUtility.actual == target, "Snap reaches the target")
        check(WindowUtility.writes == 2, "Snap costs one position write and one size write")
        check(result.isSuccessful && !result.sizeWasConstrained, "An unconstrained snap is not flagged as constrained")

        result = snap(
            original,
            to: CGRect(x: 1000, y: 600, width: 200, height: 100),
            bounds: bounds
        ) {
            WindowUtility.minimum = CGSize(width: 500, height: 300)
        }
        check(WindowUtility.actual == CGRect(x: 850, y: 500, width: 500, height: 300), "A window held at its minimum size stays centered on the frame it was aimed at")
        check(result.isSuccessful && result.sizeWasConstrained, "A clamped resize counts as successful once re-anchored")

        result = snap(original, to: target, bounds: bounds) {
            WindowUtility.minimum = CGSize(width: 900, height: 900)
        }
        check(WindowUtility.actual == CGRect(x: 540, y: 0, width: 900, height: 900), "A right-half resize that a minimum width stretches keeps its right edge on the screen")

        _ = snap(original, to: target, bounds: bounds) {
            WindowUtility.fixedWidth = original.width
        }
        check(WindowUtility.actual == CGRect(x: 840, y: 0, width: 600, height: 900), "A fixed-width window is pushed back against the target edge")

        result = snap(original, to: target, bounds: bounds) {
            WindowUtility.dropsFirstAttempt = true
        }
        check(WindowUtility.actual == target, "A dropped first attempt is written again")
        check(WindowUtility.writes == 4, "The retry is the only extra round trip")

        result = snap(original, to: target, bounds: bounds, enhancedUserInterface: true)
        check(WindowUtility.enhancedUserInterfaceLog == [false, true], "Enhanced UI is suspended for the write and restored after it")
        check(result.isSuccessful, "An enhanced UI window still reaches its target")

        result = snap(original, to: CGRect(x: 40, y: 50, width: 600, height: 400), bounds: bounds, resizable: false)
        check(WindowUtility.sizeWrites == 0, "No size write is sent to a nonresizable window")
        check(WindowUtility.actual.origin == CGPoint(x: 40, y: 50) && result.isSuccessful, "A nonresizable window still moves")

        _ = snap(original, to: otherScreen, bounds: .zero, sizeFirst: true)
        check(WindowUtility.order == ["size", "position", "size"], "Crossing screens sizes the window before moving it")

        result = snap(original, to: target, bounds: bounds) {
            WindowUtility.valid = false
        }
        check(!result.isSuccessful, "A window that stopped answering is reported as a failure")
        check(result.role == "AXWindow", "A failed snap carries the window metadata for the log")

        let preview = PreviewController()
        preview.show(frame: original)
        pump(0.08)
        guard let panel = NSApp.windows.compactMap({ $0 as? ActivePanel }).first else { fatalError("Missing preview panel") }
        check(panel.frame == NSScreen.screens[0].frame, "Preview panel stays screen-sized")
        preview.show(frame: target)
        check(panel.frame == NSScreen.screens[0].frame, "Only preview contents move")
        preview.hide()
        preview.show(frame: original, style: .danger)
        pump(0.08)
        check(panel.isVisible, "Showing during fade-out cancels stale hiding")
        preview.hide()
        pump(0.08)
        check(!panel.isVisible, "Preview hides after its transition")
        preview.show(frame: original)
        preview.hideImmediately()
        check(!panel.isVisible, "Immediate cancellation removes the preview")
        preview.show(frame: original)
        pump(0.08)
        preview.settle(frame: target)
        pump(0.08)
        check(panel.isVisible, "The box stays on screen while the window answers")
        pump(0.15)
        check(!panel.isVisible, "The box dissolves once it has been moved onto the window")
        preview.settle(frame: original)
        check(!panel.isVisible, "Settling a preview that is already gone leaves it gone")
        SettingsStore.shared.behavior.showPreview = false
        preview.show(frame: target)
        check(!panel.isVisible, "Disabled preview remains hidden")
        print("Passed \(passed) window-animation and preview checks.")
    }
}
