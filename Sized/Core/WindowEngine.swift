//
//  WindowEngine.swift
//  Sized — adapted from Loop (GPL-3.0).
//  Upstream: MrKai77/Loop, commit 573ace3, `WindowEngine.resizeWindow` /
//  `handleSizeConstrainedWindow` / `Window.setFrame(sizeFirst:)`.
//

import AppKit
import ApplicationServices
import SwiftUI

/// Loop's own way of placing a window, and its default: `animateWindowResizes` ships as
/// `false`, so nothing is interpolated. Position and size are written once, read back,
/// written again only if the app dropped the first write, and re-anchored if the app
/// clamped the size.
///
/// The frame-by-frame alternative (`WindowTransformAnimation`) costs 2-5 AX round trips
/// per frame, so a 0.3s resize becomes ~150 blocking calls into the target app; when the
/// app clamps the size the frames land late and the motion reads as stutter.
@MainActor
enum WindowEngine {
    /// Per-window AX state that every resize needs. Read once per action: probing it at
    /// each call is what made the old synchronous path pay ~10 round trips per resize.
    struct ResolvedProperties {
        let isResizable: Bool
        let enhancedUserInterface: Bool
    }

    static func resolveProperties(for window: AXUIElement) -> ResolvedProperties {
        ResolvedProperties(
            isResizable: WindowUtility.isResizable(window),
            enhancedUserInterface: WindowUtility.hasEnhancedUserInterface(window)
        )
    }

    /// Loop's `shouldAnimateResize`: apps in enhanced UI mode are never animated, because
    /// they re-layout on their own and the interpolation fights them.
    static func shouldAnimate(explicitlyEnabled: Bool, properties: ResolvedProperties) -> Bool {
        guard explicitlyEnabled,
              !properties.enhancedUserInterface,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else { return false }
        return true
    }

    static func resize(
        window: AXUIElement,
        to targetFrame: CGRect,
        bounds: CGRect,
        sizeFirst: Bool,
        properties: ResolvedProperties,
        diagnostics: Bool
    ) -> WindowResizeResult {
        let requestedFrame = targetFrame.integral
        let initialFrame = WindowUtility.frame(of: window)

        // Enhanced UI apps re-position their own windows mid-write; suspending the mode is
        // what lets the frame we asked for actually stick.
        if properties.enhancedUserInterface {
            WindowUtility.setEnhancedUserInterface(false, for: window)
        }
        defer {
            if properties.enhancedUserInterface {
                WindowUtility.setEnhancedUserInterface(true, for: window)
            }
        }

        var writes = setFrame(window, requestedFrame, sizeFirst: sizeFirst, resizable: properties.isResizable)
        var actualFrame = WindowUtility.frame(of: window)

        // An app in the middle of its own layout pass can swallow the first write.
        if let readBack = actualFrame, !readBack.approximatelyEqual(to: requestedFrame) {
            writes = setFrame(window, requestedFrame, sizeFirst: false, resizable: properties.isResizable)
            actualFrame = WindowUtility.frame(of: window)
        }

        var sizeWasConstrained = false
        if bounds != .zero,
           let readBack = actualFrame,
           properties.isResizable,
           !readBack.size.approximatelyEqual(to: requestedFrame.size, tolerance: 2) {
            let corrected = anchoredFrame(
                for: readBack.size,
                within: requestedFrame,
                targetEdges: requestedFrame.getEdgesTouchingBounds(bounds),
                bounds: bounds
            )
            if !readBack.origin.approximatelyEqual(to: corrected.origin, tolerance: 1) {
                writes.position = WindowUtility.setPositionFast(corrected.origin, for: window)
                actualFrame = corrected
                sizeWasConstrained = true
            }
        }

        var result = WindowResizeResult(
            requestedFrame: requestedFrame,
            initialFrame: initialFrame,
            actualFrame: actualFrame,
            positionResult: writes.position,
            sizeResult: writes.size,
            didCreateAXValues: true,
            sizeWasConstrained: sizeWasConstrained
        )

        // These five attributes are only for the log line, so they are read when the
        // outcome needs explaining rather than on every resize.
        if diagnostics || !result.isSuccessful {
            let metadata = WindowUtility.resizeMetadata(for: window)
            result.role = metadata.role
            result.subrole = metadata.subrole
            result.title = metadata.title
            result.positionSettable = metadata.positionSettable
            result.sizeSettable = metadata.sizeSettable
        }

        return result
    }

    /// Loop's order: position first, then size — a resize then grows away from the corner
    /// that was just placed. Only when crossing screens does the size go first, because
    /// the destination screen cannot be reached by a window still sized for the source.
    private static func setFrame(
        _ window: AXUIElement,
        _ rect: CGRect,
        sizeFirst: Bool,
        resizable: Bool
    ) -> (position: AXError, size: AXError) {
        var sizeResult: AXError = .success

        if sizeFirst, resizable {
            sizeResult = WindowUtility.setSizeFast(rect.size, for: window)
        }

        let positionResult = WindowUtility.setPositionFast(rect.origin, for: window)

        if resizable {
            sizeResult = WindowUtility.setSizeFast(rect.size, for: window)
        }

        return (positionResult, sizeResult)
    }

    /// Where a window that ended up a different size than requested should sit, so that the
    /// edge it was aimed at keeps touching the bounds instead of floating away from it. Loop
    /// derives this from the edges alone: the action's anchor already shaped `requested`, so
    /// once the app overrides the size, holding the aimed edge is what keeps the window near
    /// its preview.
    static func anchoredFrame(
        for actualSize: CGSize,
        within requested: CGRect,
        targetEdges: Edge.Set,
        bounds: CGRect
    ) -> CGRect {
        var frame = CGRect(origin: requested.origin, size: actualSize)

        if targetEdges.contains(.leading), targetEdges.contains(.trailing) {
            frame.origin.x = requested.midX - actualSize.width / 2
        } else if targetEdges.contains(.leading) {
            frame.origin.x = requested.minX
        } else if targetEdges.contains(.trailing) {
            frame.origin.x = requested.maxX - actualSize.width
        } else {
            frame.origin.x = requested.midX - actualSize.width / 2
        }

        if targetEdges.contains(.top), targetEdges.contains(.bottom) {
            frame.origin.y = requested.midY - actualSize.height / 2
        } else if targetEdges.contains(.top) {
            frame.origin.y = requested.minY
        } else if targetEdges.contains(.bottom) {
            frame.origin.y = requested.maxY - actualSize.height
        } else {
            frame.origin.y = requested.midY - actualSize.height / 2
        }

        return frame.pushInside(bounds)
    }
}

private extension CGFloat {
    func approximatelyEquals(to other: CGFloat, tolerance: CGFloat = 10) -> Bool {
        abs(self - other) < tolerance
    }
}

private extension CGPoint {
    func approximatelyEqual(to other: CGPoint, tolerance: CGFloat = 10) -> Bool {
        x.approximatelyEquals(to: other.x, tolerance: tolerance) &&
            y.approximatelyEquals(to: other.y, tolerance: tolerance)
    }
}

private extension CGSize {
    func approximatelyEqual(to other: CGSize, tolerance: CGFloat = 10) -> Bool {
        width.approximatelyEquals(to: other.width, tolerance: tolerance) &&
            height.approximatelyEquals(to: other.height, tolerance: tolerance)
    }
}

private extension CGRect {
    func approximatelyEqual(to other: CGRect, tolerance: CGFloat = 10) -> Bool {
        origin.approximatelyEqual(to: other.origin, tolerance: tolerance) &&
            size.approximatelyEqual(to: other.size, tolerance: tolerance)
    }

    func pushInside(_ bounds: CGRect) -> CGRect {
        var result = self

        if result.minX < bounds.minX {
            result.origin.x = bounds.minX
        }
        if result.minY < bounds.minY {
            result.origin.y = bounds.minY
        }
        if result.maxX > bounds.maxX {
            result.origin.x = bounds.maxX - result.width
        }
        if result.maxY > bounds.maxY {
            result.origin.y = bounds.maxY - result.height
        }

        return result
    }

    func getEdgesTouchingBounds(_ bounds: CGRect) -> Edge.Set {
        var edges: Edge.Set = []
        if minX.approximatelyEquals(to: bounds.minX) { edges.insert(.leading) }
        if minY.approximatelyEquals(to: bounds.minY) { edges.insert(.top) }
        if maxX.approximatelyEquals(to: bounds.maxX) { edges.insert(.trailing) }
        if maxY.approximatelyEquals(to: bounds.maxY) { edges.insert(.bottom) }
        return edges
    }
}
