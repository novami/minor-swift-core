import Foundation
import OSLog

/// Collects the current process's log entries plus app/OS info into a plain-text report.
public enum Diagnostics {
    public static func report(since interval: TimeInterval = 3600) throws -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        var lines = [
            "App: \(Log.subsystem) \(version)",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Date: \(Date.now.ISO8601Format())",
            ""
        ]

        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = store.position(date: Date.now.addingTimeInterval(-interval))
        let entries = try store.getEntries(at: position)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem == Log.subsystem }

        for entry in entries {
            lines.append("\(entry.date.ISO8601Format()) [\(entry.category)] \(entry.composedMessage)")
        }
        return lines.joined(separator: "\n")
    }

    public static func export(to url: URL) throws {
        try report().write(to: url, atomically: true, encoding: .utf8)
    }
}
