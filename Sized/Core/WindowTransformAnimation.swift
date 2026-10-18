//
//  WindowTransformAnimation.swift
//  Sized — adapted from Loop (GPL-3.0).
//  Upstream: mrkai77/Loop, commit 573ace3071641bbe002527ccfc0811842300ccba.
//  Modified for Sized: AX access, synchronous cancellation, explicit resize anchors,
//  display refresh rate, and exact final-frame application.
//
//  Created by Kai Azim on 2023-09-02.
//

import AppKit
import ApplicationServices
import SwiftUI

private enum ResizeAnimationConstraint {
    case none
    case fixedAxes(width: Bool, height: Bool)
    case fixedAspectRatio(CGFloat)

    var hasFixedAxes: Bool {
        if case .fixedAxes = self {
            return true
        }

        return false
    }
}

/// Animate a window's resize!
@MainActor
final class WindowTransformAnimation: NSAnimation {
    private let targetFrame: CGRect
    private let originalFrame: CGRect
    private let window: AXUIElement
    private let fallbackAnchor: CGPoint?
    private let bounds: CGRect
    private let shouldSetSize: Bool
    private let targetEdges: Edge.Set
    private let stationaryAxes: (x: Bool, y: Bool)
    private var didCallCompletionHandler: Bool = false
    private let completionHandler: (UUID, Bool) -> Void

    private var lastWindowFrame: CGRect = .zero
    private var constraint: ResizeAnimationConstraint = .none

    let id = UUID()

    init(
        from originalFrame: CGRect,
        to newRect: CGRect,
        within bounds: CGRect,
        anchor: CGPoint?,
        window: AXUIElement,
        duration: TimeInterval,
        completion: @escaping (UUID, Bool) -> Void
    ) {
        self.targetFrame = newRect
        self.originalFrame = originalFrame
        self.window = window
        self.fallbackAnchor = anchor
        self.bounds = bounds
        self.shouldSetSize = WindowUtility.isResizable(window)
        self.targetEdges = newRect.getEdgesTouchingBounds(bounds)
        self.stationaryAxes = (
            x: newRect.origin.x.approximatelyEquals(to: originalFrame.origin.x, tolerance: 2) &&
                newRect.width.approximatelyEquals(to: originalFrame.width, tolerance: 2),
            y: newRect.origin.y.approximatelyEquals(to: originalFrame.origin.y, tolerance: 2) &&
                newRect.height.approximatelyEquals(to: originalFrame.height, tolerance: 2)
        )
        self.completionHandler = completion
        super.init(duration: max(0.05, duration), animationCurve: .easeOut)
        self.frameRate = Float(max(WindowUtility.screen(forAXFrame: originalFrame).maximumFramesPerSecond, 60))
        self.animationBlockingMode = .nonblocking
        self.lastWindowFrame = originalFrame
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func start() {
        guard !didCallCompletionHandler else { return }
        super.start()
    }

    override func stop() {
        finish(cancelled: false)
    }

    func cancel() {
        finish(cancelled: true)
    }

    private func finish(cancelled: Bool) {
        guard !didCallCompletionHandler else { return }
        didCallCompletionHandler = true
        super.stop()
        completionHandler(id, cancelled)
    }

    override var currentProgress: NSAnimation.Progress {
        didSet {
            guard !didCallCompletionHandler else { return }
            apply(progress: currentValue)

            if currentValue >= 1.0 {
                stop()
            }
        }
    }

    private func apply(progress: Float) {
        let value = CGFloat(1.0 - pow(1.0 - progress, 3))

        let requestedFrame = CGRect(
            x: round(originalFrame.origin.x + value * (targetFrame.origin.x - originalFrame.origin.x)),
            y: round(originalFrame.origin.y + value * (targetFrame.origin.y - originalFrame.origin.y)),
            width: round(originalFrame.size.width + value * (targetFrame.size.width - originalFrame.size.width)),
            height: round(originalFrame.size.height + value * (targetFrame.size.height - originalFrame.size.height))
        )

        var newFrame = requestedFrame
        var currentOrigin = lastWindowFrame.origin
        let resizeTolerance: CGFloat = 2

        let sizeToSet = progress >= 1 ? targetFrame.size : sizeToSet(for: requestedFrame)
        let sizeTolerance: CGFloat = progress >= 1 ? 0.1 : resizeTolerance

        if shouldSetSize, !lastWindowFrame.size.approximatelyEqual(to: sizeToSet, tolerance: sizeTolerance) {
            let growsHorizontally = sizeToSet.width > lastWindowFrame.width + resizeTolerance
            let growsVertically = sizeToSet.height > lastWindowFrame.height + resizeTolerance

            if let preResizeOrigin = predictedPreResizeOrigin(
                requestedFrame: requestedFrame,
                sizeToSet: sizeToSet
            ) {
                if !lastWindowFrame.origin.approximatelyEqual(to: preResizeOrigin, tolerance: 1) {
                    _ = WindowUtility.setPositionFast(preResizeOrigin, for: window)
                    currentOrigin = preResizeOrigin
                }
            } else if growsHorizontally || growsVertically {
                var preResizeOrigin = lastWindowFrame.origin
                if growsHorizontally {
                    preResizeOrigin.x = requestedFrame.origin.x
                }
                if growsVertically {
                    preResizeOrigin.y = requestedFrame.origin.y
                }
                if !lastWindowFrame.origin.approximatelyEqual(to: preResizeOrigin, tolerance: 1) {
                    _ = WindowUtility.setPositionFast(preResizeOrigin, for: window)
                    currentOrigin = preResizeOrigin
                }
            }

            _ = WindowUtility.setSizeFast(sizeToSet, for: window)
            if bounds != .zero {
                guard let actualFrame = WindowUtility.frame(of: window) else {
                    cancel()
                    return
                }
                updateConstraint(actualFrame: actualFrame, requestedFrame: requestedFrame, tolerance: resizeTolerance)

                if shouldAnchorDuringAnimation(
                    actualSize: actualFrame.size,
                    requestedSize: requestedFrame.size
                ) {
                    newFrame = animationAnchoredFrame(
                        for: actualFrame.size,
                        within: requestedFrame,
                        currentOrigin: currentOrigin
                    )
                } else {
                    newFrame = CGRect(
                        origin: requestedFrame.origin,
                        size: actualFrame.size
                    )
                    .pushInside(bounds)
                }
            }
        } else if bounds != .zero, constraint.hasFixedAxes {
            newFrame = animationAnchoredFrame(
                for: lastWindowFrame.size,
                within: requestedFrame,
                currentOrigin: lastWindowFrame.origin
            )
        } else if bounds != .zero {
            newFrame = newFrame.pushInside(bounds)
        }

        if !currentOrigin.approximatelyEqual(to: newFrame.origin, tolerance: 1) {
            _ = WindowUtility.setPositionFast(newFrame.origin, for: window)
        }

        guard let actualFrame = WindowUtility.frame(of: window) else {
            cancel()
            return
        }
        lastWindowFrame = actualFrame
        if progress >= 1, bounds != .zero,
           !actualFrame.size.approximatelyEqual(to: targetFrame.size, tolerance: 2) {
            let corrected = anchoredFrame(for: actualFrame.size, within: targetFrame, targetEdges: targetEdges, bounds: bounds)
            _ = WindowUtility.setPositionFast(corrected.origin, for: window)
        }
    }

    private func animationAnchoredFrame(
        for actualSize: CGSize,
        within requestedFrame: CGRect,
        currentOrigin: CGPoint
    ) -> CGRect {
        var frame = anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        if stationaryAxes.x, actualSize.width.approximatelyEquals(to: requestedFrame.width, tolerance: 2) {
            frame.origin.x = currentOrigin.x
        }
        if stationaryAxes.y, actualSize.height.approximatelyEquals(to: requestedFrame.height, tolerance: 2) {
            frame.origin.y = currentOrigin.y
        }

        return frame.pushInside(bounds)
    }

    private func sizeToSet(for requestedFrame: CGRect) -> CGSize {
        switch constraint {
        case .none, .fixedAspectRatio:
            requestedFrame.size
        case let .fixedAxes(width, height):
            CGSize(
                width: width ? lastWindowFrame.width : requestedFrame.width,
                height: height ? lastWindowFrame.height : requestedFrame.height
            )
        }
    }

    private func predictedPreResizeOrigin(requestedFrame: CGRect, sizeToSet: CGSize) -> CGPoint? {
        guard case let .fixedAspectRatio(aspectRatio) = constraint,
              bounds != .zero else {
            return nil
        }

        let predictedSize = sizeToSet.fitting(aspectRatio: aspectRatio)
        return animationAnchoredFrame(
            for: predictedSize,
            within: requestedFrame,
            currentOrigin: lastWindowFrame.origin
        )
        .origin
    }

    private func updateConstraint(actualFrame: CGRect, requestedFrame: CGRect, tolerance: CGFloat) {
        let acceptedSize = actualFrame.size
        guard acceptedSize.width <= requestedFrame.width + tolerance,
              acceptedSize.height <= requestedFrame.height + tolerance else {
            constraint = .none
            return
        }

        let requestedWidthChanged = !requestedFrame.width.approximatelyEquals(
            to: lastWindowFrame.width,
            tolerance: tolerance
        )
        let requestedHeightChanged = !requestedFrame.height.approximatelyEquals(
            to: lastWindowFrame.height,
            tolerance: tolerance
        )

        if requestedWidthChanged, requestedHeightChanged,
           hasStableAspectRatio(acceptedSize, comparedTo: lastWindowFrame.size),
           shouldAnchorDuringAnimation(
               actualSize: acceptedSize,
               requestedSize: requestedFrame.size,
               tolerance: tolerance
           ), acceptedSize.width > 0, acceptedSize.height > 0 {
            constraint = .fixedAspectRatio(acceptedSize.width / acceptedSize.height)
            return
        }

        if case .fixedAxes = constraint {
            return
        }

        let shouldLockWidth = shouldLockSizeAxis(
            actual: actualFrame.width,
            previous: lastWindowFrame.width,
            requested: requestedFrame.width,
            tolerance: tolerance
        )

        let shouldLockHeight = shouldLockSizeAxis(
            actual: actualFrame.height,
            previous: lastWindowFrame.height,
            requested: requestedFrame.height,
            tolerance: tolerance
        )

        if didSizeChange(acceptedSize, comparedTo: lastWindowFrame.size, tolerance: tolerance),
           hasStableAspectRatio(acceptedSize, comparedTo: lastWindowFrame.size),
           shouldAnchorDuringAnimation(
               actualSize: acceptedSize,
               requestedSize: requestedFrame.size,
               tolerance: tolerance
           ), acceptedSize.width > 0, acceptedSize.height > 0 {
            constraint = .fixedAspectRatio(acceptedSize.width / acceptedSize.height)
            return
        }

        if shouldLockWidth || shouldLockHeight {
            constraint = .fixedAxes(width: shouldLockWidth, height: shouldLockHeight)
        }
    }

    private func didSizeChange(_ size: CGSize, comparedTo previousSize: CGSize, tolerance: CGFloat) -> Bool {
        !size.approximatelyEqual(to: previousSize, tolerance: tolerance)
    }

    private func hasStableAspectRatio(_ size: CGSize, comparedTo previousSize: CGSize) -> Bool {
        guard size.width > 0, size.height > 0,
              previousSize.width > 0, previousSize.height > 0 else {
            return false
        }

        return (size.width / size.height).approximatelyEquals(
            to: previousSize.width / previousSize.height,
            tolerance: 0.01
        )
    }

    private func shouldLockSizeAxis(
        actual: CGFloat,
        previous: CGFloat,
        requested: CGFloat,
        tolerance: CGFloat
    ) -> Bool {
        let requestedChanged = !requested.approximatelyEquals(to: previous, tolerance: tolerance)
        let actualDidNotChange = actual.approximatelyEquals(to: previous, tolerance: tolerance)
        let constrainedBelowRequest = actual <= requested + tolerance

        return requestedChanged && actualDidNotChange && constrainedBelowRequest
    }

    private func shouldAnchorDuringAnimation(actualSize: CGSize, requestedSize: CGSize, tolerance: CGFloat = 2) -> Bool {
        !actualSize.approximatelyEqual(to: requestedSize, tolerance: tolerance) &&
            actualSize.width <= requestedSize.width + tolerance &&
            actualSize.height <= requestedSize.height + tolerance
    }

    private func anchoredFrame(for size: CGSize, within requested: CGRect, targetEdges: Edge.Set, bounds: CGRect) -> CGRect {
        let anchor = fallbackAnchor ?? CGPoint(
            x: targetEdges.contains(.leading) == targetEdges.contains(.trailing) ? 0.5 : (targetEdges.contains(.leading) ? 0 : 1),
            y: targetEdges.contains(.top) == targetEdges.contains(.bottom) ? 0.5 : (targetEdges.contains(.top) ? 0 : 1)
        )
        return CGRect(
            x: requested.minX + anchor.x * (requested.width - size.width),
            y: requested.minY + anchor.y * (requested.height - size.height),
            width: size.width,
            height: size.height
        ).pushInside(bounds)
    }
}

private extension CGFloat {
    func approximatelyEquals(to other: CGFloat, tolerance: CGFloat = 1) -> Bool {
        abs(self - other) < tolerance
    }
}

private extension CGPoint {
    func approximatelyEqual(to other: CGPoint, tolerance: CGFloat) -> Bool {
        x.approximatelyEquals(to: other.x, tolerance: tolerance) && y.approximatelyEquals(to: other.y, tolerance: tolerance)
    }
}

private extension CGSize {
    func approximatelyEqual(to other: CGSize, tolerance: CGFloat) -> Bool {
        width.approximatelyEquals(to: other.width, tolerance: tolerance) && height.approximatelyEquals(to: other.height, tolerance: tolerance)
    }

    func fitting(aspectRatio: CGFloat) -> CGSize {
        guard width > 0, height > 0, aspectRatio > 0 else { return self }
        return width / height > aspectRatio
            ? CGSize(width: height * aspectRatio, height: height)
            : CGSize(width: width, height: width / aspectRatio)
    }
}

private extension CGRect {
    func pushInside(_ bounds: CGRect) -> CGRect {
        CGRect(
            x: size.width >= bounds.width ? bounds.minX : min(max(minX, bounds.minX), bounds.maxX - width),
            y: size.height >= bounds.height ? bounds.minY : min(max(minY, bounds.minY), bounds.maxY - height),
            width: width,
            height: height
        )
    }

    func getEdgesTouchingBounds(_ bounds: CGRect) -> Edge.Set {
        var edges: Edge.Set = []
        if minX.approximatelyEquals(to: bounds.minX) { edges.insert(.leading) }
        if maxX.approximatelyEquals(to: bounds.maxX) { edges.insert(.trailing) }
        if minY.approximatelyEquals(to: bounds.minY) { edges.insert(.top) }
        if maxY.approximatelyEquals(to: bounds.maxY) { edges.insert(.bottom) }
        return edges
    }
}
