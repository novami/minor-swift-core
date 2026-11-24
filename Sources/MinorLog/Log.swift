import Foundation
import os

/// Unified logging: subsystem = bundle ID, category = area of the app.
public enum Log {
    public static let subsystem = Bundle.main.bundleIdentifier ?? "MinorSwiftCore"

    public static func logger(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
