import AppKit
import ApplicationServices
import Combine

@MainActor
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    private var refreshTask: Task<Void, Never>?

    private init() {}

    func refresh() {
        let currentValue = AXIsProcessTrusted()
        guard isTrusted != currentValue else { return }

        isTrusted = currentValue
        if currentValue {
            stopAutoRefresh()
        }
    }

    func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        openPrivacySettings()
        startAutoRefresh()
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            for _ in 0..<120 {
                guard let self, !Task.isCancelled else { return }
                self.refresh()
                guard !self.isTrusted else { return }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
