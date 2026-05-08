//
//  SizedApp.swift
//  Sized
//
//  Created by 白凯浩 on 2026/5/8.
//

import SwiftUI

@main
struct SizedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .environmentObject(settings)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置...") {
                    SizedManager.shared.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
