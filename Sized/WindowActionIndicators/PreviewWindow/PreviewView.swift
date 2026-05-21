import SwiftUI

struct PreviewView: View {
    var settings: BehaviorSettings
    var style: WindowActionPreviewStyle = .standard

    private var fillColor: Color {
        switch style {
        case .standard:
            Color(hex: settings.previewBackgroundColorHex).opacity(0.16)
        case .danger:
            Color.red.opacity(0.34)
        }
    }

    private var strokeColor: Color {
        switch style {
        case .standard:
            Color(hex: settings.previewBorderColorHex)
        case .danger:
            Color.red.opacity(0.92)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: CGFloat(settings.previewCornerRadius), style: .continuous)
            .fill(fillColor)
            .overlay {
                RoundedRectangle(cornerRadius: CGFloat(settings.previewCornerRadius), style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: CGFloat(settings.previewBorderWidth))
            }
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }
}
