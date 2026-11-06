import ApplicationServices
import CoreGraphics

/// What one resize attempt left behind: what was asked for, where the window actually
/// ended up, and the AX errors collected on the way.
struct WindowResizeResult {
    let requestedFrame: CGRect
    let initialFrame: CGRect?
    let actualFrame: CGRect?
    var role: String? = nil
    var subrole: String? = nil
    var title: String? = nil
    var positionSettable: Bool? = nil
    var sizeSettable: Bool? = nil
    let positionResult: AXError
    let sizeResult: AXError
    let didCreateAXValues: Bool

    /// The app refused the requested size (minimum size, fixed aspect ratio, fixed width…)
    /// and the window was re-anchored instead. That is the best achievable result, not a
    /// failure, so it must not suppress haptic feedback or raise a diagnostic error.
    var sizeWasConstrained: Bool = false

    var apiSucceeded: Bool {
        didCreateAXValues && positionResult == .success && sizeResult == .success
    }

    var reachedTarget: Bool {
        guard let actualFrame else { return false }
        return Self.framesAreClose(actualFrame, requestedFrame)
    }

    var isSuccessful: Bool {
        reachedTarget || sizeWasConstrained
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
            "reachedTarget=\(reachedTarget)",
            "sizeWasConstrained=\(sizeWasConstrained)"
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
