import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case wheelStyle
    case wheelAssignment
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wheelStyle: "轮盘样式"
        case .wheelAssignment: "尺寸分配"
        case .general: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .wheelStyle: "paintpalette"
        case .wheelAssignment: "circle.grid.cross"
        case .general: "gearshape"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var selection: SettingsPage? = .wheelStyle

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $selection) { page in
                Label(page.title, systemImage: page.systemImage)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 260)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            switch selection ?? .wheelStyle {
            case .wheelStyle:
                WheelStylePage()
            case .wheelAssignment:
                WheelAssignmentPage()
            case .general:
                GeneralSettingsPage()
            }
        }
        .frame(minWidth: 920, minHeight: 660)
        .background(AppBackgroundView())
    }
}

private struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            VisualEffectView(material: .windowBackground, blendingMode: .behindWindow, state: .active)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(nsColor: .windowBackgroundColor), Color(red: 0.08, green: 0.09, blue: 0.1)]
                    : [Color(nsColor: .windowBackgroundColor), Color(red: 0.93, green: 0.96, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.55)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore.shared)
}
