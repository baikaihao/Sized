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
        SettingsPageContainer {
            Text("尺寸分配".localized)
                .font(.largeTitle.bold())

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
                        exportText = (try? settings.exportAssignmentsJSON()) ?? ""
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
        .sheet(isPresented: $showingExport) {
            JSONSheet(title: "导出尺寸分配", text: $exportText, error: nil, primaryTitle: "完成") {
                showingExport = false
            }
        }
        .sheet(isPresented: $showingImport) {
            JSONSheet(title: "导入尺寸分配", text: $importText, error: importError, primaryTitle: "导入") {
                do {
                    try settings.importAssignmentsJSON(importText)
                    showingImport = false
                } catch {
                    importError = "尺寸分配格式无效：%@".localizedFormat(error.localizedDescription)
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
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 28) {
                visualEditor
                    .frame(width: 430)

                detailPanel
                    .frame(minWidth: 560, maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 20) {
                visualEditor
                    .frame(maxWidth: .infinity)

                detailPanel
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visualEditor: some View {
        SettingsSection(title: "可视化编辑器", systemImage: "circle.grid.cross") {
            AssignmentGrid(assignments: $assignments, selectedSlot: $selectedSlot)
                .frame(maxWidth: .infinity)
        }
    }

    private var detailPanel: some View {
        AssignmentDetailPanel(slot: selectedSlot, action: selectedAction)
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
                Picker("模式", selection: $action.mode) {
                    ForEach(WindowActionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: action.mode) { _, newMode in
                    normalizeAction(for: newMode)
                }

                TextField("显示名称（可选）", text: $action.customLabel)
                    .textFieldStyle(.roundedBorder)

                actionSummary
            }

            modeConfiguration
        }
        .frame(maxWidth: .infinity)
    }

    private var actionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(action.displayName, systemImage: action.systemImage)
                    .font(.headline)
                Spacer()
            }
            Text(action.sizeDisplayName)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var modeConfiguration: some View {
        switch action.mode {
        case .fixedSize:
            fixedSizeConfiguration
        case .screenLayout:
            screenLayoutConfiguration
        case .relativeScale:
            relativeScaleConfiguration
        case .windowCommand:
            windowCommandConfiguration
        case .noAction:
            noActionConfiguration
        }
    }

    private var fixedSizeConfiguration: some View {
        Group {
            SettingsSection(title: "固定尺寸", systemImage: WindowActionMode.fixedSize.systemImage) {
                Picker("尺寸", selection: $action.fixedSizeKind) {
                    ForEach(SizePresetCategory.allCases.filter { $0 != .utility }) { category in
                        Section(category.displayName) {
                            ForEach(SizePresetKind.fixedSizeSelectable.filter { $0.category == category }) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                    }
                }

                Label("选择该槽位后，Sized 会把目标窗口改为选中的宽高。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if action.fixedSizeKind == .custom {
                SettingsSection(title: "自定义尺寸", systemImage: "slider.horizontal.3") {
                    NumericField(title: "宽度", value: $action.customSize.width)
                    NumericField(title: "高度", value: $action.customSize.height)
                    Label("仅修改窗口大小，窗口位置由设置中的锚点规则决定。", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var screenLayoutConfiguration: some View {
        SettingsSection(title: "屏幕布局", systemImage: WindowActionMode.screenLayout.systemImage) {
            Picker("布局", selection: $action.screenLayout) {
                ForEach(ScreenLayoutAction.allCases) { layout in
                    Label(layout.displayName, systemImage: layout.systemImage).tag(layout)
                }
            }

            Label(screenLayoutDescription, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var relativeScaleConfiguration: some View {
        SettingsSection(title: "相对缩放", systemImage: WindowActionMode.relativeScale.systemImage) {
            Picker("方向", selection: $action.scaleDirection) {
                ForEach(RelativeScaleDirection.allCases) { direction in
                    Label(direction.displayName, systemImage: direction.systemImage).tag(direction)
                }
            }
            .onChange(of: action.scaleDirection) { _, newDirection in
                action.scalePercent = RadialMenuAction.clampedScalePercent(action.scalePercent, direction: newDirection)
            }

            Picker("锚点", selection: $action.scaleAnchor) {
                ForEach(RelativeScaleAnchor.allCases) { anchor in
                    Text(anchor.displayName).tag(anchor)
                }
            }

            ScalePercentRow(direction: action.scaleDirection, percent: $action.scalePercent)

            Label("基于当前窗口大小按比例变化；放大超过可见工作区时，会铺满可见区域。", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var windowCommandConfiguration: some View {
        SettingsSection(title: "窗口命令", systemImage: WindowActionMode.windowCommand.systemImage) {
            Picker("命令", selection: $action.windowCommand) {
                ForEach(WindowCommandAction.allCases) { command in
                    Label(command.displayName, systemImage: command.systemImage).tag(command)
                }
            }

            if action.windowCommand.isDestructive {
                Label("选择该槽位时，目标窗口会显示红色遮罩作为警示。", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Label("命令会作用于目标窗口或其所属应用。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var noActionConfiguration: some View {
        SettingsSection(title: "无操作", systemImage: WindowActionMode.noAction.systemImage) {
            Label("选择该槽位后不会调整窗口，也不会执行命令。", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var screenLayoutDescription: String {
        switch action.screenLayout {
        case .fillVisible:
            "铺满当前屏幕的可见工作区，不进入系统全屏。".localized
        case .systemFullScreen:
            "触发窗口绿色按钮；失败时不会自动改为铺满可见区域。".localized
        case .leftHalf, .rightHalf:
            "按当前屏幕可见工作区分成左右两栏，并移动到对应位置。".localized
        case .leftThird, .centerThird, .rightThird:
            "按当前屏幕可见工作区分成左中右三栏，并移动到对应位置。".localized
        case .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter:
            "按当前屏幕可见工作区分成四个角落，并移动到对应位置。".localized
        }
    }

    private func normalizeAction(for mode: WindowActionMode) {
        switch mode {
        case .fixedSize:
            if action.fixedSizeKind.fixedSize == nil && action.fixedSizeKind != .custom {
                action.fixedSizeKind = .large
            }
        case .screenLayout:
            break
        case .relativeScale:
            action.scalePercent = RadialMenuAction.clampedScalePercent(action.scalePercent, direction: action.scaleDirection)
            if action.scaleAnchor == .center {
                action.scaleAnchor = RelativeScaleAnchor.defaultAnchor(for: slot)
            }
        case .windowCommand:
            break
        case .noAction:
            break
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

private struct ScalePercentRow: View {
    var direction: RelativeScaleDirection
    @Binding var percent: Double

    private var clampedPercent: Binding<Double> {
        Binding(
            get: { RadialMenuAction.clampedScalePercent(percent, direction: direction) },
            set: { percent = RadialMenuAction.clampedScalePercent($0, direction: direction) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("比例".localized)
                Spacer()
                TextField("比例".localized, value: clampedPercent, format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 78)
                Text("%")
                    .foregroundStyle(.secondary)
            }

            Slider(value: clampedPercent, in: direction.percentRange, step: 5)
        }
        .onAppear {
            percent = RadialMenuAction.clampedScalePercent(percent, direction: direction)
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
