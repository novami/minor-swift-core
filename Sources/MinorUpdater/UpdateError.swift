import Foundation

public enum UpdateError: LocalizedError, Equatable {
    case invalidRepository(String)
    case http(Int)
    case assetMissing(String)
    case digestMismatch
    case archiveInvalid
    case signatureInvalid(OSStatus)
    case bundleMismatch
    case notNewer
    case notWritable

    public var errorDescription: String? {
        switch self {
        case .invalidRepository(let repository): "Invalid update repository: \(repository)"
        case .http(let status): "Update server responded with HTTP \(status)"
        case .assetMissing(let name): "Release has no asset named \(name)"
        case .digestMismatch: "Downloaded file checksum does not match"
        case .archiveInvalid: "Downloaded archive does not contain an application"
        case .signatureInvalid(let status): "Update signature is not valid (OSStatus \(status))"
        case .bundleMismatch: "Downloaded application has a different bundle identifier"
        case .notNewer: "Downloaded version is not newer than the installed one"
        case .notWritable: "The application location is not writable"
        }
    }
}
