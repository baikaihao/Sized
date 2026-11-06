import AppKit
import Combine
import SwiftUI

// Uses Loop's fixed screen-sized panel and SwiftUI preview transitions.
@MainActor
final class PreviewController {
    private var panel: ActivePanel?
    private let presentation = PreviewPresentation()
    private var closeTask: Task<Void, Never>?
    private var screenFrame: CGRect?
    private var settings: SettingsStore { .shared }

    func show(frame: CGRect, style: WindowActionPreviewStyle = .standard, animated: Bool = true) {
        guard settings.behavior.showPreview else {
            hide()
            return
        }
        closeTask?.cancel()
        closeTask = nil

        let screen = WindowUtility.screen(forAXFrame: frame)
        let changedScreen = screenFrame != screen.frame
        let panel = panel ?? makePanel()
        let wasVisible = panel.isVisible
        self.panel = panel

        let inset = style == .danger ? 0 : CGFloat(settings.behavior.previewPadding)
        let appKitFrame = WindowUtility.axRectToAppKit(frame.insetBy(dx: inset, dy: inset))
        let target = CGRect(
            x: appKitFrame.minX - screen.frame.minX,
            y: screen.frame.maxY - appKitFrame.maxY,
            width: max(1, appKitFrame.width),
            height: max(1, appKitFrame.height)
        )
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        // Changing screens is immediate; animate the shape inside a stationary panel.
        if changedScreen {
            panel.setFrame(screen.frame, display: true)
            screenFrame = screen.frame
        }
        withoutAnimation {
            presentation.settings = settings.behavior
            presentation.style = style
            if !wasVisible {
                presentation.isShown = false
                presentation.frame = reduceMotion || style == .danger
                    ? target
                    : target.insetBy(dx: target.width * 0.1, dy: target.height * 0.1)
            } else if changedScreen || reduceMotion {
                presentation.frame = target
            }
        }
        panel.orderFrontRegardless()
        panel.contentView?.layoutSubtreeIfNeeded()

        if animated {
            withAnimation(previewAnimation) {
                presentation.frame = target
                presentation.isShown = true
            }
        } else {
            withoutAnimation {
                presentation.frame = target
                presentation.isShown = true
            }
        }
    }

    /// Moves the lingering box onto the frame the window actually reached, then dissolves it.
    /// A window can refuse the size it was asked for, and this is when the preview would
    /// otherwise keep describing a place the window is not.
    func settle(frame: CGRect, delay: TimeInterval = 0.12) {
        guard presentation.isShown else { return }
        show(frame: frame, animated: false)
        closeTask?.cancel()
        closeTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            self?.hide()
        }
    }

    func hide() {
        guard let panel, presentation.isShown else { return }
        closeTask?.cancel()
        withAnimation(previewAnimation) {
            presentation.isShown = false
        }
        let duration = animationDuration
        closeTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return
            }
            guard let self, !self.presentation.isShown else { return }
            panel.orderOut(nil)
            self.closeTask = nil
        }
    }

    func hideImmediately() {
        closeTask?.cancel()
        closeTask = nil
        withoutAnimation { presentation.isShown = false }
        panel?.orderOut(nil)
    }

    private var animationDuration: TimeInterval {
        let duration = min(max(settings.behavior.previewAnimationSpeed, 0.05), 0.5)
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? min(duration, 0.12) : duration
    }

    private var previewAnimation: Animation {
        // Loop's default “snappy” preview curve (AnimationConfiguration.swift).
        .timingCurve(0.22, 1, 0.47, 1, duration: animationDuration)
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }

    private func makePanel() -> ActivePanel {
        let panel = ActivePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        let hostingView = NSHostingView(rootView: PreviewOverlayView(presentation: presentation))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        return panel
    }
}

@MainActor
final class PreviewPresentation: ObservableObject {
    @Published var frame: CGRect = .zero
    @Published var isShown = false
    @Published var settings = BehaviorSettings.default
    @Published var style: WindowActionPreviewStyle = .standard
}

struct PreviewOverlayView: View {
    @ObservedObject var presentation: PreviewPresentation

    var body: some View {
        PreviewView(settings: presentation.settings, style: presentation.style)
            .compositingGroup()
            .frame(width: presentation.frame.width, height: presentation.frame.height)
            .offset(x: presentation.frame.minX, y: presentation.frame.minY)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .opacity(presentation.isShown ? 1 : 0)
    }
}
