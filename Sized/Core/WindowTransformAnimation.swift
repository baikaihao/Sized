import AppKit
import ApplicationServices

nonisolated final class WindowTransformAnimation: @unchecked Sendable {
    let id = UUID()

    private static let animationQueue = DispatchQueue(
        label: "bkh.Sized.window-transform-animation",
        qos: .userInteractive
    )

    private let originalFrame: CGRect
    private let targetFrame: CGRect
    private let targetBounds: CGRect
    private let movementBounds: CGRect?
    private let horizontalAnchor: CGFloat
    private let verticalAnchor: CGFloat
    private let window: AXUIElement
    private let duration: TimeInterval
    private let frameInterval: DispatchTimeInterval
    private let completion: @MainActor (UUID, Bool) -> Void

    private var lastAppliedFrame: CGRect
    private var timer: DispatchSourceTimer?
    private var startedAt: TimeInterval = 0
    private var didComplete = false

    @MainActor
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
        horizontalAnchor = min(max(anchor.x, 0), 1)
        verticalAnchor = min(max(anchor.y, 0), 1)
        self.window = window
        self.duration = max(0.05, duration)
        self.completion = completion
        lastAppliedFrame = originalFrame

        let sourceScreen = WindowUtility.screen(forAXFrame: originalFrame)
        let targetScreen = WindowUtility.screen(forAXFrame: targetFrame)
        movementBounds = sourceScreen == targetScreen ? bounds : nil

        let refreshRate = min(sourceScreen.maximumFramesPerSecond, 60)
        let framesPerSecond = refreshRate > 0 ? refreshRate : 60
        frameInterval = .nanoseconds(1_000_000_000 / framesPerSecond)
    }

    func start() {
        Self.animationQueue.async {
            self.startOnAnimationQueue()
        }
    }

    func cancel() {
        Self.animationQueue.async {
            self.finishOnAnimationQueue(cancelled: true)
        }
    }

    private func startOnAnimationQueue() {
        guard timer == nil, !didComplete else { return }

        startedAt = ProcessInfo.processInfo.systemUptime
        let timer = DispatchSource.makeTimerSource(queue: Self.animationQueue)
        self.timer = timer
        timer.schedule(deadline: .now(), repeating: frameInterval, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            self?.tickOnAnimationQueue()
        }
        timer.resume()
    }

    private func tickOnAnimationQueue() {
        guard !didComplete else { return }

        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        let progress = min(max(elapsed / duration, 0), 1)
        apply(progress: CGFloat(progress))

        if progress >= 1 {
            finishOnAnimationQueue(cancelled: false)
        }
    }

    private func finishOnAnimationQueue(cancelled: Bool) {
        guard !didComplete else { return }
        didComplete = true

        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil

        let id = id
        let completion = completion
        Task { @MainActor in
            completion(id, cancelled)
        }
    }

    private func apply(progress: CGFloat) {
        let easedProgress = 1 - pow(1 - min(max(progress, 0), 1), 3)
        let requestedSize = CGSize(
            width: interpolated(originalFrame.width, targetFrame.width, progress: easedProgress).rounded(),
            height: interpolated(originalFrame.height, targetFrame.height, progress: easedProgress).rounded()
        )
        let requestedAnchor = CGPoint(
            x: interpolated(
                anchorPosition(origin: originalFrame.minX, length: originalFrame.width, anchor: horizontalAnchor),
                anchorPosition(origin: targetFrame.minX, length: targetFrame.width, anchor: horizontalAnchor),
                progress: easedProgress
            ),
            y: interpolated(
                anchorPosition(origin: originalFrame.minY, length: originalFrame.height, anchor: verticalAnchor),
                anchorPosition(origin: targetFrame.minY, length: targetFrame.height, anchor: verticalAnchor),
                progress: easedProgress
            )
        )
        let requestedFrame = CGRect(
            x: requestedAnchor.x - horizontalAnchor * requestedSize.width,
            y: requestedAnchor.y - verticalAnchor * requestedSize.height,
            width: requestedSize.width,
            height: requestedSize.height
        )

        guard lastAppliedFrame.size != requestedFrame.size else {
            applyPosition(for: lastAppliedFrame.size, in: requestedFrame, progress: progress)
            return
        }

        applyPosition(for: requestedFrame.size, in: requestedFrame, progress: progress)
        let sizeResult = WindowUtility.setSizeFast(requestedFrame.size, for: window)

        var actualSize = requestedFrame.size
        if sizeResult == .success {
            actualSize = WindowUtility.size(of: window) ?? requestedFrame.size
        }

        if actualSize != requestedFrame.size {
            applyPosition(for: actualSize, in: requestedFrame, progress: progress)
        }
        lastAppliedFrame.size = actualSize
    }

    private func applyPosition(for actualSize: CGSize, in requestedFrame: CGRect, progress: CGFloat) {
        let origin = anchoredOrigin(
            for: actualSize,
            in: requestedFrame,
            clampToTargetBounds: progress >= 0.999
        )
        guard !pointsAreClose(lastAppliedFrame.origin, origin) else { return }
        if WindowUtility.setPositionFast(origin, for: window) == .success {
            lastAppliedFrame.origin = origin
        }
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

    private func anchorPosition(origin: CGFloat, length: CGFloat, anchor: CGFloat) -> CGFloat {
        origin + anchor * length
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

    private func interpolated(_ start: CGFloat, _ end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }

    private func pointsAreClose(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
        abs(lhs.x - rhs.x) < 0.1 && abs(lhs.y - rhs.y) < 0.1
    }
}
