import CryptoKit
import Foundation

/// Downloads, verifies and swaps the app bundle. All checks run before anything on disk is replaced.
struct UpdateInstaller: Sendable {
    let bundleURL: URL
    let bundleIdentifier: String
    let teamID: String
    let currentVersion: SemanticVersion

    var isLocationWritable: Bool {
        let manager = FileManager.default
        return manager.isWritableFile(atPath: bundleURL.path)
            && manager.isWritableFile(atPath: bundleURL.deletingLastPathComponent().path)
    }

    /// Returns the verified, unpacked app ready to replace the running one.
    @concurrent
    func stage(_ asset: GitHubReleaseAsset) async throws -> URL {
        let (archive, response) = try await URLSession.shared.download(from: asset.downloadURL)
        defer { try? FileManager.default.removeItem(at: archive) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw UpdateError.http(status) }

        if let digest = asset.digest {
            guard try Self.sha256(of: archive) == digest.replacingOccurrences(of: "sha256:", with: "") else {
                throw UpdateError.digestMismatch
            }
        }

        // Same volume as the installed app, so the final swap is a rename.
        let staging = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: bundleURL, create: true
        )
        try await Self.run("/usr/bin/ditto", ["-x", "-k", archive.path, staging.path])

        let contents = try FileManager.default.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil)
        guard let app = contents.first(where: { $0.pathExtension == "app" }) else { throw UpdateError.archiveInvalid }

        try CodeSignature.verify(bundle: app, identifier: bundleIdentifier, teamID: teamID)

        let info = NSDictionary(contentsOf: app.appending(path: "Contents/Info.plist"))
        guard info?["CFBundleIdentifier"] as? String == bundleIdentifier else { throw UpdateError.bundleMismatch }
        guard let raw = info?["CFBundleShortVersionString"] as? String,
              let version = SemanticVersion(raw), version > currentVersion
        else { throw UpdateError.notNewer }

        return app
    }

    func install(_ stagedApp: URL) throws {
        guard isLocationWritable else { throw UpdateError.notWritable }
        _ = try FileManager.default.replaceItemAt(bundleURL, withItemAt: stagedApp)
    }

    /// Starts a detached shell that reopens the app once this process exits.
    func scheduleRelaunch() throws {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = [
            "-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$2\"",
            "relaunch", String(ProcessInfo.processInfo.processIdentifier), bundleURL.path
        ]
        try process.run()
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func run(_ path: String, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(filePath: path)
        process.arguments = arguments
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: UpdateError.archiveInvalid)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
