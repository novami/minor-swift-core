import AppKit
import MinorLog
import Observation

/// Checks GitHub Releases of the repository in Info.plist key `MinorUpdateRepository` (`owner/repo`)
/// and installs the asset `<AppName>-<version>.zip`. Disabled for unsigned builds.
@MainActor
@Observable
public final class Updater {
    public enum State: Equatable, Sendable {
        case unavailable(String)
        case idle
        case checking
        case upToDate
        case available(SemanticVersion, notes: String?)
        case downloading
        case failed(String)
    }

    public static let infoKey = "MinorUpdateRepository"
    public static let checkInterval: TimeInterval = 24 * 3600

    public private(set) var state: State
    public private(set) var releasePage: URL?
    public var automaticChecks: Bool {
        didSet { defaults.set(automaticChecks, forKey: Keys.automatic) }
    }

    private let client: GitHubReleaseClient?
    private let installer: UpdateInstaller?
    private let assetPrefix: String
    private let defaults: UserDefaults
    private var pendingRelease: GitHubRelease?
    private var scheduler: Task<Void, Never>?
    private let log = Log.logger("Updater")

    private enum Keys {
        static let automatic = "MinorUpdater.automaticChecks"
        static let lastCheck = "MinorUpdater.lastCheck"
    }

    public init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        automaticChecks = defaults.object(forKey: Keys.automatic) as? Bool ?? true
        assetPrefix = bundle.bundleURL.deletingPathExtension().lastPathComponent
        switch Self.configure(bundle) {
        case .success(let installer, let client):
            state = .idle
            self.installer = installer
            self.client = client
        case .failure(let reason):
            state = .unavailable(reason)
            installer = nil
            client = nil
        }
    }

    private enum Configuration {
        case success(UpdateInstaller, GitHubReleaseClient)
        case failure(String)
    }

    private static func configure(_ bundle: Bundle) -> Configuration {
        let repository = bundle.object(forInfoDictionaryKey: infoKey) as? String ?? ""
        guard repository.split(separator: "/").count == 2, !repository.contains("$") else {
            return .failure("Missing \(infoKey) in Info.plist")
        }
        let rawVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let version = rawVersion.flatMap(SemanticVersion.init) else {
            return .failure("CFBundleShortVersionString is not major.minor.patch")
        }
        guard let teamID = CodeSignature.teamIdentifierOfRunningApp(), let identifier = bundle.bundleIdentifier else {
            return .failure("Updates are disabled for unsigned builds")
        }
        let installer = UpdateInstaller(
            bundleURL: bundle.bundleURL, bundleIdentifier: identifier, teamID: teamID, currentVersion: version
        )
        return .success(installer, GitHubReleaseClient(repository: repository))
    }

    public var isAvailable: Bool { installer != nil }

    /// Checks on launch and then hourly whether the daily check is due.
    public func startAutomaticChecks() {
        guard isAvailable, scheduler == nil else { return }
        scheduler = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkIfDue()
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }

    public func checkForUpdates() async {
        guard let client, let installer, state != .checking, state != .downloading else { return }
        state = .checking
        do {
            let release = try await client.latest()
            defaults.set(Date.now, forKey: Keys.lastCheck)
            releasePage = release.pageURL
            if let version = release.version, version > installer.currentVersion {
                pendingRelease = release
                state = .available(version, notes: release.notes)
                log.info("Update \(version, privacy: .public) available")
            } else {
                state = .upToDate
            }
        } catch {
            fail(error)
        }
    }

    /// Downloads, verifies, replaces the bundle and relaunches. Falls back to the release page
    /// when the app location is not writable (e.g. translocated or owned by another user).
    public func installUpdate() async {
        guard let installer, let release = pendingRelease, let version = release.version else { return }
        guard installer.isLocationWritable else {
            if let releasePage { NSWorkspace.shared.open(releasePage) }
            return
        }
        let name = "\(assetPrefix)-\(version).zip"
        guard let asset = release.assets.first(where: { $0.name == name }) else {
            fail(UpdateError.assetMissing(name))
            return
        }

        state = .downloading
        do {
            let staged = try await installer.stage(asset)
            try installer.install(staged)
            try installer.scheduleRelaunch()
            log.info("Installed \(version, privacy: .public), relaunching")
            NSApp.terminate(nil)
        } catch {
            fail(error)
        }
    }

    private func checkIfDue() async {
        guard automaticChecks else { return }
        let last = defaults.object(forKey: Keys.lastCheck) as? Date ?? .distantPast
        if Date.now.timeIntervalSince(last) >= Self.checkInterval {
            await checkForUpdates()
        }
    }

    private func fail(_ error: Error) {
        log.error("Update failed: \(error.localizedDescription, privacy: .public)")
        state = .failed(error.localizedDescription)
    }
}
