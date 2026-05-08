import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            SizedManager.shared.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            SizedManager.shared.stop()
        }
    }
}
