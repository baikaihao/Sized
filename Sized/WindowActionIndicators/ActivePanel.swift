import AppKit

@MainActor
final class ActivePanel: NSPanel {
    @objc dynamic var hasKeyAppearance: Bool { true }
    @objc dynamic var hasActiveAppearance: Bool { true }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
