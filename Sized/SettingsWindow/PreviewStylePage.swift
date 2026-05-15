import SwiftUI

struct PreviewStylePage: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var borderColor = Color(hex: BehaviorSettings.default.previewBorderColorHex)
    @State private var backgroundColor = Color(hex: BehaviorSettings.default.previewBackgroundColorHex)

    var body: some View {
        SettingsPageContainer {
            Text("预览窗口".localized)
                .font(.largeTitle.bold())

            PreviewShowcasePanel(settings: settings.behavior)

            SettingsSection(title: "基础设置", systemImage: "rectangle.dashed") {
                Toggle("显示目标尺寸预览", isOn: $settings.behavior.showPreview)
                SliderRow(title: "预览内边距", value: $settings.behavior.previewPadding, range: 0...30, step: 1, suffix: "pt")
            }

            SettingsSection(title: "边框样式", systemImage: "paintbrush") {
                SliderRow(title: "圆角半径", value: $settings.behavior.previewCornerRadius, range: 0...28, step: 1, suffix: "pt")
                SliderRow(title: "边框宽度", value: $settings.behavior.previewBorderWidth, range: 1...6, step: 1, suffix: "pt")
                ColorPicker("边框颜色", selection: $borderColor, supportsOpacity: false)
                    .onChange(of: borderColor) { _, newValue in
                        settings.behavior.previewBorderColorHex = newValue.hexString
                    }
                ColorPicker("背景颜色", selection: $backgroundColor, supportsOpacity: false)
                    .onChange(of: backgroundColor) { _, newValue in
                        settings.behavior.previewBackgroundColorHex = newValue.hexString
                    }
            }

            SettingsSection(title: "动画", systemImage: "sparkles") {
                SliderRowDecimal(title: "过渡速度", value: $settings.behavior.previewAnimationSpeed, range: 0.05...0.5, step: 0.05, suffix: "秒")
            }

            SettingsSection(title: "取消方式", systemImage: "xmark.circle") {
                Toggle("ESC 键取消轮盘", isOn: $settings.behavior.escapeCancelsRadial)
                Toggle("鼠标右键取消轮盘", isOn: $settings.behavior.rightClickCancelsRadial)
            }
        }
        .onAppear {
            borderColor = Color(hex: settings.behavior.previewBorderColorHex)
            backgroundColor = Color(hex: settings.behavior.previewBackgroundColorHex)
        }
    }
}

private struct PreviewShowcasePanel: View {
    var settings: BehaviorSettings

    var body: some View {
        SettingsSection(title: "实时预览", systemImage: "eye") {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                        .frame(width: 280, height: 180)
                        .overlay {
                            PreviewView(settings: settings)
                                .padding(CGFloat(settings.previewPadding))
                        }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)

                VStack(spacing: 6) {
                    Text("模拟目标窗口区域")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        LabeledContent("圆角", value: "\(Int(settings.previewCornerRadius))pt")
                        LabeledContent("边框", value: "\(Int(settings.previewBorderWidth))pt")
                        LabeledContent("内边距", value: "\(Int(settings.previewPadding))pt")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
