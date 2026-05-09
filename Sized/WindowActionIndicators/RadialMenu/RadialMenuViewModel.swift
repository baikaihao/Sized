import Combine
import Foundation

@MainActor
final class RadialMenuViewModel: ObservableObject {
    @Published var selectedSlot: RadialMenuSlot?
    @Published var action: RadialMenuAction?
    @Published var assignments: AssignmentSettings = .default
    @Published var hasTargetWindow = true
    @Published var isShown = false

    func update(selectedSlot: RadialMenuSlot?, action: RadialMenuAction?, assignments: AssignmentSettings, hasTargetWindow: Bool) {
        self.selectedSlot = selectedSlot
        self.action = action
        self.assignments = assignments
        self.hasTargetWindow = hasTargetWindow
    }

    func setIsShown(_ shown: Bool) {
        isShown = shown
    }
}
