import AppKit

enum HapticFeedback {
    static func selectionChanged(enabled: Bool) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func confirmed(enabled: Bool) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
