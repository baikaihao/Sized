import AppKit
import ApplicationServices
import Combine

@MainActor
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    private var refreshTask: Task<Void, Never>?
    private var lastRequestTime: Date = .distantPast
    private let requestCooldown: TimeInterval = 5

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
        refresh()
        guard !isTrusted else { return }

        let now = Date()
        guard now.timeIntervalSince(lastRequestTime) >= requestCooldown else { return }
        lastRequestTime = now

        resetStalePermissionRecords()
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let currentValue = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if currentValue {
            isTrusted = true
            stopAutoRefresh()
        } else {
            startAutoRefresh()
        }
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

    private func resetStalePermissionRecords() {
        resetPermissionRecord(service: "Accessibility")
        resetPermissionRecord(service: "ListenEvent")
    }

    private func resetPermissionRecord(service: String) {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service, bundleIdentifier]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return
        }
        process.waitUntilExit()
    }
}
