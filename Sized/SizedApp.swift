import SwiftUI

@main
struct SizedApp: App {
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup("Sized") {
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
                    SizedManager.shared.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {}
        }
    }

    @MainActor
    private func startServices() {
        AppIconProvider.shared.start()
        SizedManager.shared.start()
        SizedManager.shared.openSettings()
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
