import Foundation
import Security

public struct KeychainError: Error, Equatable {
    public let status: OSStatus

    public var message: String {
        SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
    }
}

/// Generic-password storage scoped by service (typically the bundle ID).
public struct Keychain: Sendable {
    public let service: String

    public init(service: String = Bundle.main.bundleIdentifier ?? "MinorSwiftCore") {
        self.service = service
    }

    public func set(_ data: Data, for account: String) throws {
        let query = baseQuery(account)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            try check(SecItemAdd(item as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    public func data(for account: String) throws -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try check(status)
        return result as? Data
    }

    public func set(_ string: String, for account: String) throws {
        try set(Data(string.utf8), for: account)
    }

    public func string(for account: String) throws -> String? {
        try data(for: account).flatMap { String(bytes: $0, encoding: .utf8) }
    }

    public func remove(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }

    private func baseQuery(_ account: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }
}
