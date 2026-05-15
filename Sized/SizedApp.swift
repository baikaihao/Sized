import SwiftUI

@main
struct SizedApp: App {
    private static let mainWindowID = "main"

    @Environment(\.openWindow) private var openWindow
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup("Sized", id: Self.mainWindowID) {
            SettingsView()
                .environmentObject(settings)
                .background(AppLifecycleView(onAppear: startServices))
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
    private func startServices() {
        AppIconProvider.shared.start()
        StatusItemController.shared.configure(openSized: openMainWindow)
        SizedManager.shared.start()
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
