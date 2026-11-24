import Foundation
import Security

enum CodeSignature {
    /// Team ID of the running app, or nil when it is unsigned / ad-hoc signed (local dev builds).
    static func teamIdentifierOfRunningApp() -> String? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
                == errSecSuccess
        else { return nil }
        return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Requires a valid Developer ID Application signature from the given team for the given bundle ID.
    static func verify(bundle url: URL, identifier: String, teamID: String) throws {
        let requirementText = """
            anchor apple generic and identifier "\(identifier)" \
            and certificate 1[field.1.2.840.113635.100.6.2.6] \
            and certificate leaf[field.1.2.840.113635.100.6.1.13] \
            and certificate leaf[subject.OU] = "\(teamID)"
            """
        var staticCode: SecStaticCode?
        var requirement: SecRequirement?
        try check(SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode))
        try check(SecRequirementCreateWithString(requirementText as CFString, [], &requirement))
        guard let staticCode, let requirement else { throw UpdateError.signatureInvalid(errSecInternalError) }

        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        try check(SecStaticCodeCheckValidity(staticCode, flags, requirement))
    }

    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw UpdateError.signatureInvalid(status) }
    }
}
