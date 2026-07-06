import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppIconProvider.shared.start()
        SizedManager.shared.start()
    }
}

@main
struct SizedApp: App {
    private static let mainWindowID = "main"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup("Sized", id: Self.mainWindowID) {
            SettingsView()
                .environmentObject(settings)
                .background(AppLifecycleView(onAppear: configureStatusItem))
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
        if let window = NSApp.windows.first(where: { $0.title == "Sized" }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: Self.mainWindowID)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func configureStatusItem() {
        StatusItemController.shared.configure(openSized: openMainWindow)
    }
}

private struct AppLifecycleView: NSViewRepresentable {
    let onAppear: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onAppear()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
