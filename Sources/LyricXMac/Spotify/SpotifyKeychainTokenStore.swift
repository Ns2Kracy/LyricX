import Foundation
import Security

public protocol SpotifyRefreshTokenStore: Sendable {
    func load() throws -> String?
    func save(_ refreshToken: String) throws
    func delete() throws
}

public struct SpotifyKeychainTokenStore: SpotifyRefreshTokenStore, Sendable {
    private let service: String
    private let account: String

    public init(
        service: String = "com.lyricx.menu-bar.spotify",
        account: String = "refresh-token"
    ) {
        self.service = service
        self.account = account
    }

    public func load() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw SpotifyKeychainError.operationFailed(status)
        }
        return token
    }

    public func save(_ refreshToken: String) throws {
        let data = Data(refreshToken.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw SpotifyKeychainError.operationFailed(updateStatus)
        }

        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SpotifyKeychainError.operationFailed(addStatus)
        }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SpotifyKeychainError.operationFailed(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public struct SpotifyKeychainError: LocalizedError, Equatable {
    public let status: OSStatus

    init(_ status: OSStatus) {
        self.status = status
    }

    public var errorDescription: String? {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
        return "Spotify session storage failed: \(detail)"
    }

    static func operationFailed(_ status: OSStatus) -> SpotifyKeychainError {
        SpotifyKeychainError(status)
    }
}
