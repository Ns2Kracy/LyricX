import CryptoKit
import Foundation
import Network
import Security

public struct SpotifyPKCE: Equatable, Sendable {
    public let verifier: String
    public let challenge: String
    public let state: String

    public init(verifier: String, state: String) {
        self.verifier = verifier
        self.challenge = Self.challenge(for: verifier)
        self.state = state
    }

    public static func generate() throws -> SpotifyPKCE {
        SpotifyPKCE(
            verifier: try randomBase64URL(byteCount: 64),
            state: try randomBase64URL(byteCount: 32)
        )
    }

    public static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func randomBase64URL(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw SpotifyAuthorizationError.randomGenerationFailed
        }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

public struct SpotifyAccessToken: Sendable {
    public let value: String
    public let expiresAt: Date
    public let scopes: Set<String>

    public var isExpiring: Bool {
        expiresAt.timeIntervalSinceNow < 30
    }
}

public enum SpotifyConnectionStatus: Equatable, Sendable {
    case unavailable(String)
    case disconnected
    case connecting
    case connected
    case failed(String)

    public var title: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .disconnected:
            return "Not Connected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .failed:
            return "Connection Failed"
        }
    }

    public var detail: String? {
        switch self {
        case .unavailable(let message), .failed(let message):
            return message
        default:
            return nil
        }
    }

    public var isConnected: Bool {
        self == .connected
    }

    public var isConnecting: Bool {
        self == .connecting
    }

    public var canConnect: Bool {
        switch self {
        case .disconnected, .failed:
            return true
        case .unavailable, .connecting, .connected:
            return false
        }
    }
}

public actor SpotifyAuthorizationService {
    public static let scopes = [
        "streaming",
        "user-modify-playback-state",
        "user-read-playback-state"
    ]

    private let configuration: SpotifyConfiguration
    private let tokenStore: any SpotifyRefreshTokenStore
    private let session: URLSession
    private var currentToken: SpotifyAccessToken?
    private var refreshToken: String?
    private var refreshTask: Task<SpotifyTokenResponse, Error>?
    private var sessionGeneration: UInt = 0

    public init(
        configuration: SpotifyConfiguration,
        tokenStore: any SpotifyRefreshTokenStore = SpotifyKeychainTokenStore(),
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.session = session
    }

    public func connect(
        openURL: @escaping @Sendable (URL) async -> Bool
    ) async throws -> SpotifyAccessToken {
        let generation = sessionGeneration
        let pkce = try SpotifyPKCE.generate()
        let server = try SpotifyLoopbackCallbackServer(
            path: configuration.redirectPath,
            expectedState: pkce.state
        )
        let redirectURI = try await server.start()
        defer { server.stop() }

        let url = try Self.authorizationURL(
            configuration: configuration,
            redirectURI: redirectURI,
            pkce: pkce
        )
        guard await openURL(url) else {
            throw SpotifyAuthorizationError.browserOpenFailed
        }

        let callback = try await server.waitForCallback(timeout: .seconds(180))
        if let error = callback.error {
            throw SpotifyAuthorizationError.authorizationDenied(error)
        }
        guard let code = callback.code else {
            throw SpotifyAuthorizationError.missingAuthorizationCode
        }

        guard generation == sessionGeneration else {
            throw SpotifyAuthorizationError.notConnected
        }
        let response = try await Self.tokenRequest([
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "code_verifier", value: pkce.verifier)
        ], session: session)
        guard generation == sessionGeneration else {
            throw SpotifyAuthorizationError.notConnected
        }
        return try accept(response: response, existingRefreshToken: nil)
    }

    public func restore() async throws -> Bool {
        guard let storedRefreshToken = try tokenStore.load() else {
            return false
        }
        refreshToken = storedRefreshToken
        _ = try await requestRefreshedAccessToken(using: storedRefreshToken)
        return true
    }

    public func accessToken() async throws -> SpotifyAccessToken {
        if let currentToken, !currentToken.isExpiring {
            return currentToken
        }
        let availableRefreshToken = if let refreshToken {
            refreshToken
        } else {
            try tokenStore.load()
        }
        guard let availableRefreshToken else {
            throw SpotifyAuthorizationError.notConnected
        }
        return try await requestRefreshedAccessToken(using: availableRefreshToken)
    }

    public func refreshAccessToken() async throws -> SpotifyAccessToken {
        let availableRefreshToken = if let refreshToken {
            refreshToken
        } else {
            try tokenStore.load()
        }
        guard let availableRefreshToken else {
            throw SpotifyAuthorizationError.notConnected
        }
        return try await requestRefreshedAccessToken(using: availableRefreshToken)
    }

    public func disconnect() throws {
        sessionGeneration &+= 1
        refreshTask?.cancel()
        refreshTask = nil
        currentToken = nil
        refreshToken = nil
        try tokenStore.delete()
    }

    public nonisolated static func authorizationURL(
        configuration: SpotifyConfiguration,
        redirectURI: URL,
        pkce: SpotifyPKCE
    ) throws -> URL {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "state", value: pkce.state),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: pkce.challenge)
        ]
        guard let url = components?.url else {
            throw SpotifyAuthorizationError.invalidAuthorizationURL
        }
        return url
    }

    private func requestRefreshedAccessToken(using refreshToken: String) async throws -> SpotifyAccessToken {
        let generation = sessionGeneration
        let response: SpotifyTokenResponse
        if let refreshTask {
            do {
                response = try await refreshTask.value
            } catch {
                if generation != sessionGeneration {
                    throw SpotifyAuthorizationError.notConnected
                }
                throw error
            }
        } else {
            let form = [
                URLQueryItem(name: "grant_type", value: "refresh_token"),
                URLQueryItem(name: "refresh_token", value: refreshToken),
                URLQueryItem(name: "client_id", value: configuration.clientID)
            ]
            let session = session
            let task = Task {
                try await Self.tokenRequest(form, session: session)
            }
            refreshTask = task
            do {
                response = try await task.value
            } catch {
                refreshTask = nil
                if generation != sessionGeneration {
                    throw SpotifyAuthorizationError.notConnected
                }
                throw error
            }
            refreshTask = nil
        }
        guard generation == sessionGeneration else {
            throw SpotifyAuthorizationError.notConnected
        }
        return try accept(response: response, existingRefreshToken: refreshToken)
    }

    private func accept(
        response: SpotifyTokenResponse,
        existingRefreshToken: String?
    ) throws -> SpotifyAccessToken {
        let accessToken = response.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let responseRefreshToken = response.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedRefreshToken = responseRefreshToken?.isEmpty == false
            ? responseRefreshToken
            : existingRefreshToken
        guard !accessToken.isEmpty, response.expiresIn > 0 else {
            throw SpotifyAuthorizationError.invalidTokenResponse
        }
        guard let savedRefreshToken, !savedRefreshToken.isEmpty else {
            throw SpotifyAuthorizationError.missingRefreshToken
        }
        try tokenStore.save(savedRefreshToken)

        let token = SpotifyAccessToken(
            value: accessToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            scopes: Set(response.scope.split(separator: " ").map(String.init))
        )
        refreshToken = savedRefreshToken
        currentToken = token
        return token
    }

    private nonisolated static func tokenRequest(
        _ form: [URLQueryItem],
        session: URLSession
    ) async throws -> SpotifyTokenResponse {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw SpotifyAuthorizationError.invalidTokenURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = form
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyAuthorizationError.invalidTokenResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SpotifyAuthorizationError.tokenRequestFailed(statusCode: httpResponse.statusCode)
        }
        do {
            return try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        } catch {
            throw SpotifyAuthorizationError.invalidTokenResponse
        }
    }
}

public enum SpotifyAuthorizationError: LocalizedError, Equatable {
    case authorizationDenied(String)
    case browserOpenFailed
    case callbackFailed
    case callbackTimedOut
    case invalidAuthorizationURL
    case invalidCallback
    case invalidState
    case invalidTokenResponse
    case invalidTokenURL
    case missingAuthorizationCode
    case missingRefreshToken
    case notConnected
    case randomGenerationFailed
    case tokenRequestFailed(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Spotify authorization was denied"
        case .browserOpenFailed:
            return "Could not open the Spotify authorization page"
        case .callbackFailed:
            return "Spotify did not return a valid callback"
        case .callbackTimedOut:
            return "Spotify authorization timed out"
        case .invalidAuthorizationURL, .invalidTokenURL:
            return "Spotify authorization is not configured correctly"
        case .invalidCallback, .missingAuthorizationCode:
            return "Spotify returned an invalid authorization response"
        case .invalidState:
            return "Spotify authorization state did not match"
        case .invalidTokenResponse:
            return "Spotify returned an invalid token response"
        case .missingRefreshToken:
            return "Spotify did not return a reusable session"
        case .notConnected:
            return "Spotify is not connected"
        case .randomGenerationFailed:
            return "Could not create a secure Spotify authorization request"
        case .tokenRequestFailed(let statusCode):
            return "Spotify token request failed (HTTP \(statusCode))"
        }
    }
}

private struct SpotifyTokenResponse: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

private struct SpotifyOAuthCallback: Sendable {
    let code: String?
    let error: String?
}

private final class SpotifyLoopbackCallbackServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.lyricx.spotify-oauth-callback")
    private let listener: NWListener
    private let path: String
    private let expectedState: String
    private let ready = OneShot<URL>()
    private let callback = OneShot<SpotifyOAuthCallback>()

    init(path: String, expectedState: String) throws {
        guard let port = NWEndpoint.Port(rawValue: SpotifyConfiguration.redirectPort) else {
            throw SpotifyAuthorizationError.callbackFailed
        }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: port)
        self.listener = try NWListener(using: parameters)
        self.path = path
        self.expectedState = expectedState
    }

    func start() async throws -> URL {
        listener.stateUpdateHandler = { [weak self] state in
            self?.handle(state: state)
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.start(queue: queue)
        return try await ready.wait()
    }

    func waitForCallback(timeout: Duration) async throws -> SpotifyOAuthCallback {
        try await withThrowingTaskGroup(of: SpotifyOAuthCallback.self) { group in
            group.addTask { try await self.callback.wait() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw SpotifyAuthorizationError.callbackTimedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw SpotifyAuthorizationError.callbackFailed
            }
            return result
        }
    }

    func stop() {
        listener.cancel()
    }

    private func handle(state: NWListener.State) {
        switch state {
        case .ready:
            guard let port = listener.port,
                  let url = URL(string: "http://127.0.0.1:\(port.rawValue)\(path)") else {
                ready.resolve(.failure(SpotifyAuthorizationError.callbackFailed))
                return
            }
            ready.resolve(.success(url))
        case .failed:
            ready.resolve(.failure(SpotifyAuthorizationError.callbackFailed))
            callback.resolve(.failure(SpotifyAuthorizationError.callbackFailed))
        default:
            break
        }
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(from: connection, accumulated: Data())
    }

    private func receiveRequest(from connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4_096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var requestData = accumulated
            if let data {
                requestData.append(data)
            }
            guard error == nil, requestData.count <= 16_384 else {
                self.respond(to: connection, success: false)
                return
            }
            if requestData.range(of: Data("\r\n\r\n".utf8)) != nil
                || requestData.range(of: Data("\n\n".utf8)) != nil {
                self.process(requestData: requestData, from: connection)
            } else if isComplete {
                self.respond(to: connection, success: false)
            } else {
                self.receiveRequest(from: connection, accumulated: requestData)
            }
        }
    }

    private func process(requestData: Data, from connection: NWConnection) {
        guard let request = String(data: requestData, encoding: .utf8),
              let requestTarget = Self.requestTarget(from: request),
              let components = URLComponents(string: "http://127.0.0.1\(requestTarget)"),
              components.path == path else {
            respond(to: connection, success: false)
            return
        }

        var parameters: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard parameters.updateValue(item.value ?? "", forKey: item.name) == nil else {
                respond(to: connection, success: false)
                return
            }
        }
        guard parameters["state"] == expectedState else {
            respond(to: connection, success: false)
            return
        }

        let code = parameters["code"]
        let authorizationError = parameters["error"]
        guard (code?.isEmpty == false) != (authorizationError?.isEmpty == false) else {
            respond(to: connection, success: false)
            return
        }

        callback.resolve(.success(SpotifyOAuthCallback(code: code, error: authorizationError)))
        respond(to: connection, success: true)
    }

    private func respond(to connection: NWConnection, success: Bool) {
        let status = success ? "200 OK" : "400 Bad Request"
        let message = success
            ? "Spotify authorization finished. You can close this window and return to LyricX."
            : "Spotify could not be connected. Return to LyricX and try again."
        let body = "<html><body><p>\(message)</p></body></html>"
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func requestTarget(from request: String) -> String? {
        let parts = request.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        guard parts?.count == 3, parts?.first == "GET" else {
            return nil
        }
        return String(parts?[1] ?? "")
    }
}

private final class OneShot<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, Error>?
    private var continuation: CheckedContinuation<Value, Error>?

    func wait() async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if let result {
                    lock.unlock()
                    continuation.resume(with: result)
                } else {
                    self.continuation = continuation
                    lock.unlock()
                }
            }
        } onCancel: {
            resolve(.failure(CancellationError()))
        }
    }

    func resolve(_ result: Result<Value, Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
