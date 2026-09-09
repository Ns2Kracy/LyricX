import Foundation

public struct SpotifyConfiguration: Equatable, Sendable {
    public let clientID: String
    public let redirectPath: String

    public init(clientID: String, redirectPath: String = "/callback") throws {
        let clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty, !clientID.contains("$(") else {
            throw SpotifyConfigurationError.missingClientID
        }
        guard redirectPath.hasPrefix("/"),
              !redirectPath.contains("?"),
              !redirectPath.contains("#") else {
            throw SpotifyConfigurationError.invalidRedirectPath
        }

        self.clientID = clientID
        self.redirectPath = redirectPath
    }

    public static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) throws -> SpotifyConfiguration {
        let clientID = environment["SPOTIFY_CLIENT_ID"]
            ?? bundle.object(forInfoDictionaryKey: "SpotifyClientID") as? String
            ?? ""
        return try SpotifyConfiguration(clientID: clientID)
    }
}

public enum SpotifyConfigurationError: LocalizedError, Equatable {
    case invalidRedirectPath
    case missingClientID

    public var errorDescription: String? {
        switch self {
        case .invalidRedirectPath:
            return "Spotify redirect path is invalid"
        case .missingClientID:
            return "Spotify Client ID is not configured"
        }
    }
}
