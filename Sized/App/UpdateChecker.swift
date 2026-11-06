import Combine
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, downloadURL: URL)
        case rateLimited
        case failed
    }

    @Published private(set) var state: State = .idle

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/baikaihao/Sized/releases/latest")!
    private static let releasesPageURL = URL(string: "https://github.com/baikaihao/Sized/releases")!
    private static let dailyInterval: TimeInterval = 24 * 60 * 60
    private static let tickInterval: TimeInterval = 6 * 60 * 60
    private static let lastCheckDateKey = "Sized.UpdateChecker.lastCheckDate"

    private var checkTask: Task<Void, Never>?
    private var scheduleTimer: Timer?

    private init() {}

    func check() {
        guard state != .checking else { return }

        state = .checking
        checkTask?.cancel()
        checkTask = Task { @MainActor [weak self] in
            await self?.performCheck()
        }
    }

    func refreshSchedule() {
        scheduleTimer?.invalidate()
        scheduleTimer = nil

        guard SettingsStore.shared.general.autoCheckUpdates else { return }

        runCheckIfDue()
        // Sleeping to a fixed deadline counts uptime, so a laptop that sleeps most of the day would
        // drift past its daily check. A coarse tick re-reads the clock instead.
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            guard let updateChecker = self else { return }
            Task { @MainActor in
                updateChecker.runCheckIfDue()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        scheduleTimer = timer
    }

    private func runCheckIfDue() {
        let lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckDateKey) as? Date
        guard Date().timeIntervalSince(lastCheck ?? .distantPast) >= Self.dailyInterval else { return }
        check()
    }

    private func performCheck() async {
        let newState = await Self.fetch()
        // A transport failure leaves the day unspent so the next tick can retry; a refusal from
        // GitHub counts as today's query.
        if newState != .failed {
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckDateKey)
        }
        guard !Task.isCancelled else { return }
        state = newState
    }

    private static func fetch() async -> State {
        var request = URLRequest(url: latestReleaseURL)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            return .failed
        }

        // GitHub gives anonymous callers one request quota per IP address, so a refusal is usually
        // temporary traffic, not a broken download.
        switch (response as? HTTPURLResponse)?.statusCode {
        case 403, 429: return .rateLimited
        case 200: break
        default: return .failed
        }

        guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
            return .failed
        }

        let releasedTag = String(normalizedTag(release.tagName))
        guard isNewer(release: releasedTag, than: Bundle.main.shortVersion) else {
            return .upToDate
        }

        return .available(
            version: releasedTag,
            downloadURL: release.downloadURL ?? Self.releasesPageURL
        )
    }

    private static func normalizedTag(_ tag: String) -> Substring {
        tag.trimmingCharacters(in: .whitespacesAndNewlines).drop(while: { $0 == "v" || $0 == "V" })
    }

    private static func versionParts(_ tag: String) -> [Int] {
        normalizedTag(tag).split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }

    private static func isNewer(release: String, than local: String) -> Bool {
        let released = versionParts(release)
        let installed = versionParts(local)
        for index in 0..<max(released.count, installed.count) {
            let left = index < released.count ? released[index] : 0
            let right = index < installed.count ? installed[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }

    var downloadURL: URL? {
        let zipped = assets.first { $0.name.hasSuffix(".zip") }?.browserDownloadURL
        return zipped ?? assets.first?.browserDownloadURL
    }
}
