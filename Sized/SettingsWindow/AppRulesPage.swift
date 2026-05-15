import AppKit
import SwiftUI

struct AppRulesPage: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var selectedRuleID: AppRule.ID?
    @State private var selectedSlot: RadialMenuSlot = .right

    private var selectedRuleBinding: Binding<AppRule>? {
        guard let selectedRuleID,
              let index = settings.appRules.rules.firstIndex(where: { $0.id == selectedRuleID })
        else { return nil }

        return Binding(
            get: { settings.appRules.rules[index] },
            set: { settings.appRules.rules[index] = $0 }
        )
    }

    var body: some View {
        SettingsPageContainer {
            Text("应用规则".localized)
                .font(.largeTitle.bold())

            SettingsSection(title: "规则开关", systemImage: "switch.2") {
                Toggle("启用应用规则", isOn: $settings.appRules.isEnabled)
            }

            VStack(alignment: .leading, spacing: 16) {
                ruleList

                if let selectedRuleBinding {
                    ruleEditor(rule: selectedRuleBinding)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            selectedRuleID = selectedRuleID ?? settings.appRules.rules.first?.id
        }
    }

    private var ruleList: some View {
        SettingsSection(title: "规则列表", systemImage: "list.bullet.rectangle") {
            if settings.appRules.rules.isEmpty {
                Label("还没有应用规则", systemImage: "app.badge")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(settings.appRules.rules) { rule in
                        AppRuleRow(rule: rule, isSelected: rule.id == selectedRuleID) {
                            selectedRuleID = rule.id
                            selectedSlot = .right
                        }
                    }
                }
            }

            Divider()

            Menu {
                ForEach(availableApplications(), id: \.bundleIdentifier) { app in
                    Button {
                        addRule(for: app)
                    } label: {
                        if let icon = app.icon {
                            Label {
                                Text(app.localizedName ?? app.bundleIdentifier ?? "未命名 App".localized)
                            } icon: {
                                Image(nsImage: icon)
                            }
                        } else {
                            Text(app.localizedName ?? app.bundleIdentifier ?? "未命名 App".localized)
                        }
                    }
                }

                Divider()

                Button {
                    addManualRule()
                } label: {
                    Label("手动添加", systemImage: "plus")
                }
            } label: {
                Label("添加 App 规则", systemImage: "plus")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func ruleEditor(rule: Binding<AppRule>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "匹配设置", systemImage: "scope") {
                Toggle("启用此规则", isOn: rule.isEnabled)

                TextField("App 名称", text: rule.appName)
                    .textFieldStyle(.roundedBorder)

                TextField("Bundle Identifier", text: rule.bundleIdentifier)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button {
                        rule.wrappedValue.assignments = settings.assignments
                    } label: {
                        Label("复制默认分配", systemImage: "doc.on.doc")
                    }

                    Button {
                        rule.wrappedValue.assignments = .default
                    } label: {
                        Label("恢复默认", systemImage: "arrow.counterclockwise")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        delete(ruleID: rule.wrappedValue.id)
                    } label: {
                        Label("删除规则", systemImage: "trash")
                    }
                }
            }

            AssignmentEditor(assignments: rule.assignments, selectedSlot: $selectedSlot)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        SettingsSection(title: "规则详情", systemImage: "app.badge") {
            Label("选择一个规则，或添加当前前台 App。", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func addRule(for app: NSRunningApplication) {
        guard let bundleIdentifier = app.bundleIdentifier, !bundleIdentifier.isEmpty else { return }
        if let existing = settings.appRules.rules.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            selectedRuleID = existing.id
            return
        }

        let rule = AppRule(
            appName: app.localizedName ?? bundleIdentifier,
            bundleIdentifier: bundleIdentifier,
            assignments: settings.assignments
        )
        settings.appRules.rules.append(rule)
        selectedRuleID = rule.id
        selectedSlot = .right
    }

    private func addManualRule() {
        let rule = AppRule(
            appName: "新应用规则".localized,
            bundleIdentifier: "",
            assignments: settings.assignments
        )
        settings.appRules.rules.append(rule)
        selectedRuleID = rule.id
        selectedSlot = .right
    }

    private func delete(ruleID: AppRule.ID) {
        settings.appRules.rules.removeAll { $0.id == ruleID }
        selectedRuleID = settings.appRules.rules.first?.id
        selectedSlot = .right
    }

    private func availableApplications() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular &&
                app.processIdentifier != ProcessInfo.processInfo.processIdentifier &&
                app.bundleIdentifier?.isEmpty == false
            }
            .sorted { lhs, rhs in
                (lhs.localizedName ?? lhs.bundleIdentifier ?? "") < (rhs.localizedName ?? rhs.bundleIdentifier ?? "")
            }
    }
}

private struct AppRuleRow: View {
    var rule: AppRule
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: rule.isEnabled ? "app.badge.checkmark" : "app.badge")
                    .foregroundStyle(rule.isEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.appName.isEmpty ? "未命名 App".localized : rule.appName)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(rule.bundleIdentifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.16), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
