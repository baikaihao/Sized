import SwiftUI

struct WheelAssignmentPage: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var selectedSlot: RadialMenuSlot = .right
    @State private var exportText = ""
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var importText = ""
    @State private var importError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "尺寸分配",
                    subtitle: "为 8 个方向配置窗口尺寸；方向只用于选择，不会把窗口移动到对应角落。"
                )

                AssignmentEditor(assignments: $settings.assignments, selectedSlot: $selectedSlot)

                SettingsSection(title: "配置管理", systemImage: "doc.badge.gearshape") {
                    HStack {
                        Button {
                            settings.resetAssignments()
                        } label: {
                            Label("恢复默认分配", systemImage: "arrow.counterclockwise")
                        }

                        Spacer()

                        Button {
                            exportText = (try? settings.exportJSON()) ?? ""
                            showingExport = true
                        } label: {
                            Label("导出", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            importText = ""
                            importError = nil
                            showingImport = true
                        } label: {
                            Label("导入", systemImage: "square.and.arrow.down")
                        }
                    }
                }
            }
            .padding(32)
        }
        .sheet(isPresented: $showingExport) {
            JSONSheet(title: "导出配置", text: $exportText, error: nil, primaryTitle: "完成") {
                showingExport = false
            }
        }
        .sheet(isPresented: $showingImport) {
            JSONSheet(title: "导入配置", text: $importText, error: importError, primaryTitle: "导入") {
                do {
                    try settings.importJSON(importText)
                    showingImport = false
                } catch {
                    importError = "配置文件格式无效：%@".localizedFormat(error.localizedDescription)
                }
            }
        }
    }
}

struct AssignmentEditor: View {
    @Binding var assignments: AssignmentSettings
    @Binding var selectedSlot: RadialMenuSlot

    private var selectedAction: Binding<RadialMenuAction> {
        Binding(
            get: { assignments[selectedSlot] },
            set: { assignments[selectedSlot] = $0 }
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            SettingsSection(title: "可视化编辑器", systemImage: "circle.grid.cross") {
                AssignmentGrid(assignments: $assignments, selectedSlot: $selectedSlot)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 430)

            AssignmentDetailPanel(slot: selectedSlot, action: selectedAction)
        }
    }
}

private struct AssignmentGrid: View {
    @Binding var assignments: AssignmentSettings
    @Binding var selectedSlot: RadialMenuSlot

    private let columns = Array(repeating: GridItem(.fixed(118), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(RadialMenuSlot.assignmentGridOrder.enumerated()), id: \.offset) { _, slot in
                if let slot {
                    AssignmentGridCell(
                        slot: slot,
                        action: assignments[slot],
                        isSelected: selectedSlot == slot
                    ) {
                        selectedSlot = slot
                    }
                    .draggable(slot.rawValue)
                    .dropDestination(for: String.self) { items, _ in
                        guard let rawValue = items.first, let source = RadialMenuSlot(rawValue: rawValue), source != slot else { return false }
                        guard RadialMenuSlot.assignable.contains(source) else { return false }
                        let sourceAction = assignments[source]
                        let targetAction = assignments[slot]
                        assignments[source] = targetAction
                        assignments[slot] = sourceAction
                        selectedSlot = slot
                        return true
                    }
                } else {
                    Color.clear
                        .frame(width: 118, height: 104)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AssignmentGridCell: View {
    var slot: RadialMenuSlot
    var action: RadialMenuAction
    var isSelected: Bool
    var onSelect: () -> Void

    private var fillColor: Color {
        isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08)
    }

    private var strokeColor: Color {
        isSelected ? Color.accentColor : Color.secondary.opacity(0.2)
    }

    private var strokeWidth: CGFloat {
        isSelected ? 2 : 1
    }

    var body: some View {
        Button(action: onSelect) {
            cellContent
        }
        .buttonStyle(.plain)
        .background(cellBackground)
        .overlay(cellBorder)
    }

    private var cellContent: some View {
        VStack(spacing: 10) {
            Text(slot.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(action.displayName)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(action.sizeDisplayName)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 118, height: 104)
        .contentShape(Rectangle())
    }

    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(fillColor)
    }

    private var cellBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(strokeColor, lineWidth: strokeWidth)
    }
}

private struct AssignmentDetailPanel: View {
    var slot: RadialMenuSlot
    @Binding var action: RadialMenuAction

    var body: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "%@ 槽位".localizedFormat(slot.displayName), systemImage: slot.systemImage) {
                Picker("尺寸", selection: $action.kind) {
                    ForEach(SizePresetCategory.allCases) { category in
                        Section(category.displayName) {
                            ForEach(SizePresetKind.selectable.filter { $0.category == category }) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                    }
                }

                TextField("显示名称（可选）", text: $action.customLabel)
                    .textFieldStyle(.roundedBorder)

                HStack {
            Text(action.kind.displayName.localized)
                        .font(.headline)
                    Spacer()
                }
                Text(action.sizeDisplayName)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                .padding(.top, 4)
            }

            if action.kind == .custom {
                SettingsSection(title: "自定义尺寸", systemImage: "slider.horizontal.3") {
                    NumericField(title: "宽度", value: $action.customSize.width)
                    NumericField(title: "高度", value: $action.customSize.height)
                    Label("仅修改窗口大小，窗口位置由设置中的锚点规则决定。", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsSection(title: "调整规则", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
                Label("选择该槽位后，Sized 会把当前焦点窗口改为选中的宽高，并尽量保持当前位置关系。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NumericField: View {
    var title: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title.localized)
            Spacer()
            TextField(title.localized, value: $value, format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
        }
    }
}

private struct JSONSheet: View {
    var title: String
    @Binding var text: String
    var error: String?
    var primaryTitle: String
    var primaryAction: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.localized)
                .font(.title2.weight(.semibold))

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(width: 620, height: 360)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.quaternary)
                }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(primaryTitle) { primaryAction() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }
}
