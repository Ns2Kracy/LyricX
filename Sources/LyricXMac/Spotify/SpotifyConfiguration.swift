import Foundation

public struct SpotifyConfiguration: Equatable, Sendable {
    public let clientID: String
    public let redirectPath: String

    public init(clientID: String, redirectPath: String = "/callback") throws {
        let clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty, !clientID.contains("$(") else {
            throw SpotifyConfigurationError.missingClientID
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
    case missingClientID

    public var errorDescription: String? {
        "Spotify Client ID is not configured"
    }
}
