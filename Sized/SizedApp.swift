import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppIconProvider.shared.start()
        SizedManager.shared.start()
        UpdateChecker.shared.refreshSchedule()
    }
}

@main
struct SizedApp: App {
    private static let mainWindowID = "main"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        let _ = configureStatusItem()

        WindowGroup("Sized", id: Self.mainWindowID) {
            SettingsView()
                .environmentObject(settings)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    SizedManager.shared.refreshPermissions()
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置...") {
                    openMainWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {}
        }
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if bringMainWindowToFront() {
            return
        }

        openWindow(id: Self.mainWindowID)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            _ = self.bringMainWindowToFront()
        }
    }

    @discardableResult
    private func bringMainWindowToFront() -> Bool {
        if let window = NSApp.windows.first(where: { $0.title == "Sized" }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            return true
        }
        return false
    }

    @MainActor
    private func configureStatusItem() {
        StatusItemController.shared.configure(openSized: openMainWindow)
    }
}
