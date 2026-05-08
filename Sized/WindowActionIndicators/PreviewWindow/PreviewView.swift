import SwiftUI

struct PreviewView: View {
    var settings: BehaviorSettings

    var body: some View {
        RoundedRectangle(cornerRadius: CGFloat(settings.previewCornerRadius), style: .continuous)
            .fill(Color(hex: settings.previewBackgroundColorHex).opacity(0.16))
            .overlay {
                RoundedRectangle(cornerRadius: CGFloat(settings.previewCornerRadius), style: .continuous)
                    .strokeBorder(Color(hex: settings.previewBorderColorHex), lineWidth: CGFloat(settings.previewBorderWidth))
            }
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }
}
