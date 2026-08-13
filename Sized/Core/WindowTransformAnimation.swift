import AppKit
import ApplicationServices

@MainActor
final class WindowTransformAnimation: NSAnimation {
    let id = UUID()

    private let originalFrame: CGRect
    private let targetFrame: CGRect
    private let targetBounds: CGRect
    private let movementBounds: CGRect?
    private let horizontalAnchor: CGFloat
    private let verticalAnchor: CGFloat
    private let window: AXUIElement
    private let completion: @MainActor (UUID, Bool) -> Void

    private var lastAppliedFrame: CGRect
    private var didComplete = false

    init(
        from originalFrame: CGRect,
        to targetFrame: CGRect,
        within bounds: CGRect,
        anchor: CGPoint,
        window: AXUIElement,
        duration: TimeInterval,
        completion: @escaping @MainActor (UUID, Bool) -> Void
    ) {
        self.originalFrame = originalFrame
        self.targetFrame = targetFrame
        targetBounds = bounds
        self.window = window
        self.completion = completion
        lastAppliedFrame = originalFrame

        let edgeTolerance: CGFloat = 2
        horizontalAnchor = Self.axisAnchor(
            targetMinimum: targetFrame.minX,
            targetMaximum: targetFrame.maxX,
            boundsMinimum: bounds.minX,
            boundsMaximum: bounds.maxX,
            fallback: anchor.x,
            tolerance: edgeTolerance
        )
        verticalAnchor = Self.axisAnchor(
            targetMinimum: targetFrame.minY,
            targetMaximum: targetFrame.maxY,
            boundsMinimum: bounds.minY,
            boundsMaximum: bounds.maxY,
            fallback: anchor.y,
            tolerance: edgeTolerance
        )

        let sourceScreen = WindowUtility.screen(forAXFrame: originalFrame)
        let targetScreen = WindowUtility.screen(forAXFrame: targetFrame)
        movementBounds = sourceScreen == targetScreen ? bounds : nil

        super.init(duration: max(0.05, duration), animationCurve: .easeOut)

        let refreshRate = sourceScreen.maximumFramesPerSecond
        frameRate = Float(refreshRate > 0 ? refreshRate : 60)
        animationBlockingMode = .nonblocking
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented", file: #fileID)
    }

    override var currentProgress: NSAnimation.Progress {
        didSet {
            apply(progress: CGFloat(currentValue))
            if currentProgress >= 1 {
                stop()
            }
        }
    }

    override func stop() {
        super.stop()
        finish(cancelled: false)
    }

    func cancel() {
        super.stop()
        finish(cancelled: true)
    }

    private func finish(cancelled: Bool) {
        guard !didComplete else { return }
        didComplete = true
        completion(id, cancelled)
    }

    private func apply(progress: CGFloat) {
        let easedProgress = 1 - pow(1 - min(max(progress, 0), 1), 3)
        let requestedFrame = CGRect(
            x: interpolated(originalFrame.minX, targetFrame.minX, progress: easedProgress).rounded(),
            y: interpolated(originalFrame.minY, targetFrame.minY, progress: easedProgress).rounded(),
            width: interpolated(originalFrame.width, targetFrame.width, progress: easedProgress).rounded(),
            height: interpolated(originalFrame.height, targetFrame.height, progress: easedProgress).rounded()
        )

        let sizeChanged = progress >= 0.999
            ? lastAppliedFrame.size != requestedFrame.size
            : !sizesAreClose(lastAppliedFrame.size, requestedFrame.size)
        guard sizeChanged else {
            if !pointsAreClose(lastAppliedFrame.origin, requestedFrame.origin),
               WindowUtility.setPositionFast(requestedFrame.origin, for: window) == .success {
                lastAppliedFrame.origin = requestedFrame.origin
            }
            return
        }

        var currentOrigin = lastAppliedFrame.origin
        var preResizeOrigin = currentOrigin
        let growsHorizontally = requestedFrame.width > lastAppliedFrame.width + 1
        let growsVertically = requestedFrame.height > lastAppliedFrame.height + 1

        if growsHorizontally {
            preResizeOrigin.x = requestedFrame.minX
        }
        if growsVertically {
            preResizeOrigin.y = requestedFrame.minY
        }
        if !pointsAreClose(currentOrigin, preResizeOrigin),
           WindowUtility.setPositionFast(preResizeOrigin, for: window) == .success {
            currentOrigin = preResizeOrigin
        }

        _ = WindowUtility.setSizeFast(requestedFrame.size, for: window)

        let actualFrame = WindowUtility.frame(of: window) ?? CGRect(origin: currentOrigin, size: requestedFrame.size)
        let finalOrigin: CGPoint
        let actualFitsInsideRequest = actualFrame.width <= requestedFrame.width + 2 &&
            actualFrame.height <= requestedFrame.height + 2
        if sizesAreClose(actualFrame.size, requestedFrame.size) {
            finalOrigin = requestedFrame.origin
        } else if actualFitsInsideRequest || progress >= 0.999 {
            finalOrigin = anchoredOrigin(
                for: actualFrame.size,
                in: requestedFrame,
                clampToTargetBounds: progress >= 0.999
            )
        } else {
            if let movementBounds {
                finalOrigin = clampedOrigin(requestedFrame.origin, size: actualFrame.size, within: movementBounds)
            } else {
                finalOrigin = requestedFrame.origin
            }
        }

        var appliedOrigin = actualFrame.origin
        if !pointsAreClose(appliedOrigin, finalOrigin),
           WindowUtility.setPositionFast(finalOrigin, for: window) == .success {
            appliedOrigin = finalOrigin
        }

        lastAppliedFrame = CGRect(origin: appliedOrigin, size: actualFrame.size)
    }

    private func anchoredOrigin(
        for actualSize: CGSize,
        in requestedFrame: CGRect,
        clampToTargetBounds: Bool
    ) -> CGPoint {
        let origin = CGPoint(
            x: requestedFrame.minX + horizontalAnchor * (requestedFrame.width - actualSize.width),
            y: requestedFrame.minY + verticalAnchor * (requestedFrame.height - actualSize.height)
        )
        if clampToTargetBounds {
            return clampedOrigin(origin, size: actualSize, within: targetBounds)
        }
        if let movementBounds {
            return clampedOrigin(origin, size: actualSize, within: movementBounds)
        }
        return origin
    }

    private func clampedOrigin(_ origin: CGPoint, size: CGSize, within bounds: CGRect) -> CGPoint {
        var origin = origin
        if size.width >= bounds.width {
            origin.x = bounds.minX
        } else {
            origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        }
        if size.height >= bounds.height {
            origin.y = bounds.minY
        } else {
            origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        }
        return origin
    }

    private static func axisAnchor(
        targetMinimum: CGFloat,
        targetMaximum: CGFloat,
        boundsMinimum: CGFloat,
        boundsMaximum: CGFloat,
        fallback: CGFloat,
        tolerance: CGFloat
    ) -> CGFloat {
        let touchesMinimum = abs(targetMinimum - boundsMinimum) <= tolerance
        let touchesMaximum = abs(targetMaximum - boundsMaximum) <= tolerance
        if touchesMinimum && touchesMaximum {
            return 0.5
        }
        if touchesMinimum {
            return 0
        }
        if touchesMaximum {
            return 1
        }
        return min(max(fallback, 0), 1)
    }

    private func interpolated(_ start: CGFloat, _ end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }

    private func pointsAreClose(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
        abs(lhs.x - rhs.x) < 1 && abs(lhs.y - rhs.y) < 1
    }

    private func sizesAreClose(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        abs(lhs.width - rhs.width) < 2 && abs(lhs.height - rhs.height) < 2
    }
}
