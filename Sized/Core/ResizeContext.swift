import ApplicationServices
import CoreGraphics
import Foundation

struct ResizeContext {
    var applicationPID: pid_t?
    var initialFrame: CGRect?
    var lastFrame: CGRect?

    mutating func remember(pid: pid_t, frame: CGRect) {
        if applicationPID != pid {
            applicationPID = pid
            initialFrame = frame
            lastFrame = nil
            return
        }

        lastFrame = frame
        if initialFrame == nil {
            initialFrame = frame
        }
    }
}
