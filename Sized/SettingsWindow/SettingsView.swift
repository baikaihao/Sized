import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case wheelStyle
    case wheelAssignment
    case appRules
    case previewStyle
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wheelStyle: "轮盘样式".localized
        case .wheelAssignment: "尺寸分配".localized
        case .appRules: "应用规则".localized
        case .previewStyle: "预览窗口".localized
        case .general: "设置".localized
        }
    }

    var systemImage: String {
        switch self {
        case .wheelStyle: "paintpalette"
        case .wheelAssignment: "circle.grid.cross"
        case .appRules: "app.badge"
        case .previewStyle: "rectangle.dashed"
        case .general: "gearshape"
        }
    }
}

struct SettingsView: View {
    @State private var selection: SettingsPage = .wheelStyle

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            detailView
                .frame(minWidth: 760, minHeight: 540)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .wheelStyle:
            WheelStylePage()
        case .wheelAssignment:
            WheelAssignmentPage()
        case .appRules:
            AppRulesPage()
        case .previewStyle:
            PreviewStylePage()
        case .general:
            GeneralSettingsPage()
        }
    }
}

private struct SettingsSidebar: View {
    @EnvironmentObject private var settings: SettingsStore
    @Binding var selection: SettingsPage

    var body: some View {
        List(SettingsPage.allCases, selection: $selection) { page in
            Label(page.title, systemImage: page.systemImage)
                .tag(page)
        }
        .navigationTitle("Sized")
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.wheelStyle.isVisible) {
                    Label("显示轮盘".localized, systemImage: "circle.grid.cross")
                }
                .toggleStyle(.switch)

                Divider()

                Text("Sized")
                    .font(.headline)
                Text("触发键拖动选择窗口尺寸".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

struct SettingsPageContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct SettingsSection<Content: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title.localized, systemImage: systemImage)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary)
        }
    }
}
