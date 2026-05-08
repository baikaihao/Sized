import Combine
import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var wheelStyle: WheelStyleSettings {
        didSet { persist() }
    }

    @Published var assignments: AssignmentSettings {
        didSet { persist() }
    }

    @Published var trigger: TriggerSettings {
        didSet { persist() }
    }

    @Published var behavior: BehaviorSettings {
        didSet { persist() }
    }

    @Published var general: GeneralSettings {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let settingsKey = "Sized.AppSettings.v2"
    private var isLoading = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let snapshot: AppSettingsSnapshot
        if
            let data = defaults.data(forKey: settingsKey),
            let decoded = try? JSONDecoder().decode(AppSettingsSnapshot.self, from: data)
        {
            snapshot = decoded
        } else {
            snapshot = .default
        }

        wheelStyle = snapshot.wheelStyle
        assignments = snapshot.assignments
        trigger = snapshot.trigger
        behavior = snapshot.behavior
        general = snapshot.general
    }

    var snapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(
            wheelStyle: wheelStyle,
            assignments: assignments,
            trigger: trigger,
            behavior: behavior,
            general: general
        )
    }

    func resetAll() {
        let defaults = AppSettingsSnapshot.default
        isLoading = true
        wheelStyle = defaults.wheelStyle
        assignments = defaults.assignments
        trigger = defaults.trigger
        behavior = defaults.behavior
        general = defaults.general
        isLoading = false
        persist()
    }

    func resetAssignments() {
        assignments = .default
    }

    func exportJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        return String(decoding: data, as: UTF8.self)
    }

    func importJSON(_ text: String) throws {
        let data = Data(text.utf8)
        let decoded = try JSONDecoder().decode(AppSettingsSnapshot.self, from: data)
        isLoading = true
        wheelStyle = decoded.wheelStyle
        assignments = decoded.assignments
        trigger = decoded.trigger
        behavior = decoded.behavior
        general = decoded.general
        isLoading = false
        persist()
    }

    private func persist() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: settingsKey)
    }
}
