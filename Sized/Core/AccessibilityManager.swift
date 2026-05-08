import AppKit
import ApplicationServices
import Combine

@MainActor
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    private init() {}

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        openPrivacySettings()
        refresh()
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
