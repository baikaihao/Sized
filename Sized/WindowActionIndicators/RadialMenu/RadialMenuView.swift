import SwiftUI

struct RadialMenuView: View {
    static let contentPadding: CGFloat = 64

    static func canvasSize(for style: WheelStyleSettings) -> CGFloat {
        CGFloat(style.size) + contentPadding * 2
    }

    var selectedSlot: RadialMenuSlot?
    var action: RadialMenuAction?
    var style: WheelStyleSettings
    var hasTargetWindow: Bool
    var isShown: Bool
    var isPreview: Bool = false

    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    private var ringSize: CGFloat { CGFloat(style.size) }
    private var thickness: CGFloat { min(CGFloat(style.thickness), ringSize / 2) }
    private var cornerRadius: CGFloat { CGFloat(style.cornerRadius) }
    private var accent: Color {
        switch style.accentColorMode {
        case .system, .wallpaper:
            Color.accentColor
        case .custom:
            Color(hex: style.primaryColorHex)
        }
    }
    private var secondaryAccent: Color { Color(hex: style.secondaryColorHex) }
    private var canvasSize: CGFloat { Self.canvasSize(for: style) }

    var body: some View {
        ZStack {
            if style.isVisible || isPreview {
                ring
                    .opacity(style.hideWhenNoSelection && selectedSlot == nil && !isPreview ? 0 : 1)
            }

            centerBadge
        }
        .frame(width: canvasSize, height: canvasSize)
        .scaleEffect(isShown ? 1 : 1.18)
        .opacity(isShown ? 1 : 0)
        .animation(style.appearanceAnimation ? .easeOut(duration: 0.12) : nil, value: isShown)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var ring: some View {
        ZStack {
            baseMaterial
                .frame(width: ringSize, height: ringSize)
                .mask(ringShape.fill(style: FillStyle(eoFill: true)))

            if let selectedSlot {
                DirectionSelectorSegmentShape(angle: selectedSlot.angleDegrees)
                    .fill(selectorFill)
                    .frame(width: ringSize, height: ringSize)
                    .mask(ringShape.fill(style: FillStyle(eoFill: true)))
                    .animation(animation(for: style.angleAnimation), value: selectedSlot)
            }

            ringShape
                .stroke(borderColor, lineWidth: 1)
                .frame(width: ringSize, height: ringSize)

            slotLabels
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.18), radius: 18, y: 8)
    }

    private var slotLabels: some View {
        ZStack {
            ForEach(RadialMenuSlot.directional) { slot in
                let isSelected = selectedSlot == slot
                Text(compactLabel(for: settings.assignments[slot]))
                    .font(.system(size: labelFontSize, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(colorScheme == .dark ? 0.82 : 0.72))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .frame(width: labelWidth)
                    .background {
                        Capsule()
                            .fill(labelBackground(isSelected: isSelected))
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(labelBorder(isSelected: isSelected), lineWidth: 0.6)
                    }
                    .offset(labelOffset(for: slot))
            }
        }
        .frame(width: canvasSize, height: canvasSize)
    }

    @ViewBuilder
    private var baseMaterial: some View {
        if #available(macOS 26.0, *) {
            ringShape
                .fill(.regularMaterial)
                .glassEffect(.regular.tint(accent.opacity(0.08)), in: .rect(cornerRadius: effectiveCornerRadius))
        } else {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
        }
    }

    private var ringShape: RadialRingShape {
        RadialRingShape(cornerRadius: effectiveCornerRadius, thickness: thickness)
    }

    private var centerBadge: some View {
        let badgeSize = max(CGFloat(44), ringSize - thickness * 2 - 6)
        let borderColor: Color = selectedSlot == .center ? accent : Color.secondary.opacity(0.25)
        let borderWidth: CGFloat = selectedSlot == .center ? 2 : 1

        return centerBadgeView(
            badgeSize: badgeSize,
            borderColor: borderColor,
            borderWidth: borderWidth
        )
    }

    private func centerBadgeView(badgeSize: CGFloat, borderColor: Color, borderWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .frame(width: badgeSize, height: badgeSize)
                .overlay {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                }

            Text(centerLabel)
                .font(.system(size: centerFontSize(for: badgeSize), weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(hasTargetWindow ? Color.primary : Color.secondary)
                .frame(width: max(24, badgeSize - 10))
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    private var selectorFill: some ShapeStyle {
        if style.useGradient {
            return AnyShapeStyle(LinearGradient(colors: [accent, secondaryAccent], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(accent.opacity(colorScheme == .dark ? 0.72 : 0.85))
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    private var effectiveCornerRadius: CGFloat {
        min(cornerRadius, ringSize / 2)
    }

    private var accessibilityLabel: String {
        if !hasTargetWindow { return "没有可调整的窗口" }
        if let action { return "选中 \(action.displayName)" }
        return "轮盘"
    }

    private var centerLabel: String {
        guard hasTargetWindow else { return "无窗口" }
        return compactLabel(for: action ?? settings.assignments[.center])
    }

    private var labelWidth: CGFloat {
        switch ringSize {
        case ..<90: 46
        case ..<130: 54
        default: 64
        }
    }

    private var labelFontSize: CGFloat {
        switch ringSize {
        case ..<90: 7
        case ..<130: 8
        case ..<170: 9
        default: 10
        }
    }

    private func centerFontSize(for badgeSize: CGFloat) -> CGFloat {
        switch badgeSize {
        case ..<48: 7
        case ..<58: 8
        default: 10
        }
    }

    private func compactLabel(for action: RadialMenuAction) -> String {
        if action.kind == .custom {
            return "\(Int(action.customSize.width))x\(Int(action.customSize.height))"
        }

        if let size = action.kind.fixedSize {
            return "\(Int(size.width))x\(Int(size.height))"
        }

        switch action.kind {
        case .restoreInitial:
            return "恢复"
        case .undo:
            return "撤销"
        case .none:
            return "无"
        default:
            return action.displayName
        }
    }

    private func labelOffset(for slot: RadialMenuSlot) -> CGSize {
        let availableRadius = (canvasSize - labelWidth) / 2
        let radius = min(ringSize / 2 + 18, max(ringSize / 2 - thickness / 2, availableRadius))
        let radians = slot.angleDegrees * .pi / 180
        return CGSize(width: cos(radians) * radius, height: -sin(radians) * radius)
    }

    private func labelBackground(isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(accent.opacity(colorScheme == .dark ? 0.88 : 0.92))
        }
        return AnyShapeStyle(.thinMaterial)
    }

    private func labelBorder(isSelected: Bool) -> Color {
        isSelected ? Color.white.opacity(0.22) : borderColor
    }

    private func animation(for style: RadialAnimationStyle) -> Animation? {
        switch style {
        case .none: nil
        case .smooth: .easeInOut(duration: 0.16)
        case .spring: .spring(response: 0.22, dampingFraction: 0.78)
        }
    }
}
