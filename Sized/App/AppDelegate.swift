import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            SizedManager.shared.start()
            SizedManager.shared.openSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            SizedManager.shared.stop()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            SizedManager.shared.refreshPermissions()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            SizedManager.shared.openSettings()
        }
        return false
    }
}
