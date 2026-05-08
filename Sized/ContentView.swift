//
//  ContentView.swift
//  Sized
//
//  Created by 白凯浩 on 2026/5/8.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        SettingsView()
            .environmentObject(SettingsStore.shared)
    }
}

