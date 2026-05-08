import AppKit
import CoreGraphics
import Combine
import IOKit

@MainActor
final class InputMonitoringManager: ObservableObject {
    static let shared = InputMonitoringManager()

    @Published private(set) var isTrusted: Bool = false
    @Published private(set) var statusText: String = "正在检查输入监听权限"

    private init() {
        refresh()
    }

    func refresh() {
        let hidAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        let hasHIDAccess = hidAccess == kIOHIDAccessTypeGranted
        let canListenToCGEvents = CGPreflightListenEventAccess()

        isTrusted = hasHIDAccess && canListenToCGEvents
        statusText = switch (hidAccess, canListenToCGEvents) {
        case (kIOHIDAccessTypeGranted, true):
            "已获得输入监听权限"
        case (kIOHIDAccessTypeDenied, _):
            "输入监听权限已被拒绝，请在系统设置中打开"
        case (_, false):
            "需要输入监听权限才能响应全局快捷键和鼠标中键"
        default:
            "需要输入监听权限，请点击打开系统设置"
        }
    }

    @discardableResult
    func requestAccess() -> Bool {
        let hidGranted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let cgGranted = CGRequestListenEventAccess()
        refresh()

        if !(hidGranted && cgGranted && isTrusted) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.openPrivacySettings()
            }
        }

        return isTrusted
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }
}
