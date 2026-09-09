import Foundation
import LyricXCore
import LyricXMac

extension LyricXUnitTests {
    static func testSpotifyPKCEUsesSHA256Challenge() throws {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        try expectEqual(
            SpotifyPKCE.challenge(for: verifier),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        )
    }

    static func testSpotifyAuthorizationURLRequestsPlaybackScopes() throws {
        let configuration = try SpotifyConfiguration(clientID: "test-client")
        let redirectURI = try require(
            URL(string: "http://127.0.0.1:49123/callback"),
            "Redirect URL should be valid"
        )
        let url = try SpotifyAuthorizationService.authorizationURL(
            configuration: configuration,
            redirectURI: redirectURI,
            pkce: SpotifyPKCE(verifier: "verifier", state: "expected-state")
        )
        let components = try require(
            URLComponents(url: url, resolvingAgainstBaseURL: false),
            "Authorization URL should be parseable"
        )

        try expectEqual(queryValue("client_id", in: components), "test-client")
        try expectEqual(queryValue("state", in: components), "expected-state")
        try expectEqual(
            queryValue("scope", in: components),
            SpotifyAuthorizationService.scopes.joined(separator: " ")
        )
        try expectEqual(
            SpotifyAuthorizationService.scopes,
            ["streaming", "user-modify-playback-state", "user-read-playback-state"]
        )
    }

    static func testSpotifyAuthorizationDeduplicatesConcurrentRefresh() async throws {
        let recorder = HTTPRequestRecorder()
        let session = URLProtocolStub.makeSession { request in
            recorder.append(request)
            Thread.sleep(forTimeInterval: 0.1)
            return .json(#"{"access_token":"access-test","expires_in":3600,"scope":"streaming"}"#)
        }
        defer { session.invalidateAndCancel() }

        let authorization = SpotifyAuthorizationService(
            configuration: try SpotifyConfiguration(clientID: "test-client"),
            tokenStore: FixedRefreshTokenStore(token: "refresh-test"),
            session: session
        )
        async let first = authorization.accessToken()
        async let second = authorization.accessToken()
        let tokens = try await [first, second]

        try expectEqual(tokens.map(\.value), ["access-test", "access-test"])
        try expectEqual(recorder.requests.count, 1)
    }

    static func testSpotifyDisconnectRejectsLateRefreshResponse() async throws {
        let recorder = HTTPRequestRecorder()
        let gate = HTTPResponseGate()
        let session = URLProtocolStub.makeSession { request in
            recorder.append(request)
            gate.wait()
            return .json(#"{"access_token":"late-access","expires_in":3600,"scope":"streaming"}"#)
        }
        defer {
            gate.open()
            session.invalidateAndCancel()
        }

        let authorization = SpotifyAuthorizationService(
            configuration: try SpotifyConfiguration(clientID: "test-client"),
            tokenStore: FixedRefreshTokenStore(token: "refresh-test"),
            session: session
        )
        let tokenTask = Task { try await authorization.accessToken() }
        for _ in 0..<100 where recorder.requests.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }
        _ = try require(recorder.requests.first, "Refresh request should start")

        try await authorization.disconnect()
        gate.open()
        switch await tokenTask.result {
        case .success:
            throw TestFailure(
                message: "A refresh response must not restore a disconnected session",
                file: #file,
                line: #line
            )
        case .failure(let error):
            try expectEqual(error as? SpotifyAuthorizationError, .notConnected)
        }
    }

    static func testSpotifyWebAPIDecodesMetadataAndTransfersPlayback() async throws {
        let recorder = HTTPRequestRecorder()
        let session = URLProtocolStub.makeSession { request in
            recorder.append(request)
            if request.url?.host == "accounts.spotify.com" {
                return .json(#"{"access_token":"access-test","expires_in":3600,"scope":"streaming user-modify-playback-state user-read-playback-state"}"#)
            }
            if request.httpMethod == "PUT" {
                return HTTPStubResponse(statusCode: 204)
            }
            return .json(#"""
            {
              "device":{"id":"device-1","is_active":true,"name":"MacBook","type":"Computer"},
              "progress_ms":12500,
              "is_playing":true,
              "item":{
                "album":{"images":[{"url":"https://i.scdn.co/image/test"}],"name":"Album"},
                "artists":[{"name":"Artist"}],
                "duration_ms":180000,
                "external_ids":{"isrc":"USRC17607839"},
                "id":"track-1",
                "name":"Track",
                "type":"track",
                "uri":"spotify:track:track-1"
              }
            }
            """#)
        }
        defer { session.invalidateAndCancel() }

        let configuration = try SpotifyConfiguration(clientID: "test-client")
        let authorization = SpotifyAuthorizationService(
            configuration: configuration,
            tokenStore: FixedRefreshTokenStore(token: "refresh-test"),
            session: session
        )
        let client = SpotifyWebAPIClient(
            authorizationService: authorization,
            session: session,
            baseURL: URL(string: "https://api.test/v1")!
        )

        let context = try await client.currentPlayback()
        try expectEqual(context?.device?.name, "MacBook")
        try expectEqual(context?.snapshot.track?.sourceID, "track-1")
        try expectEqual(context?.snapshot.track?.sourceURI, "spotify:track:track-1")
        try expectEqual(context?.snapshot.track?.isrc, "USRC17607839")
        try expectEqual(context?.snapshot.position, 12.5)

        try await client.transferPlayback(to: "lyricx-device", play: true)
        let transferRequest = try require(
            recorder.requests.last { $0.httpMethod == "PUT" },
            "Transfer request should be recorded"
        )
        try expectEqual(transferRequest.value(forHTTPHeaderField: "Authorization"), "Bearer access-test")
        let bodyData = try require(transferRequest.body, "Transfer request should include JSON")
        let body = try require(
            try JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
            "Transfer request JSON should be an object"
        )
        try expectEqual(body["device_ids"] as? [String], ["lyricx-device"])
        try expectEqual(body["play"] as? Bool, true)
    }

    static func testSpotifyWebAPIRetries401AndHandlesNoPlayback() async throws {
        let recorder = HTTPRequestRecorder()
        let session = URLProtocolStub.makeSession { request in
            recorder.append(request)
            if request.url?.host == "accounts.spotify.com" {
                let count = recorder.requests.filter { $0.url?.host == "accounts.spotify.com" }.count
                return .json(
                    "{\"access_token\":\"access-\(count)\",\"expires_in\":3600,\"scope\":\"streaming\"}"
                )
            }
            let count = recorder.requests.filter { $0.url?.host == "api.test" }.count
            return HTTPStubResponse(statusCode: count == 1 ? 401 : 204)
        }
        defer { session.invalidateAndCancel() }

        let authorization = SpotifyAuthorizationService(
            configuration: try SpotifyConfiguration(clientID: "test-client"),
            tokenStore: FixedRefreshTokenStore(token: "refresh-test"),
            session: session
        )
        let client = SpotifyWebAPIClient(
            authorizationService: authorization,
            session: session,
            baseURL: URL(string: "https://api.test/v1")!
        )

        try expectNil(try await client.currentPlayback())
        let apiRequests = recorder.requests.filter { $0.url?.host == "api.test" }
        try expectEqual(apiRequests.count, 2)
        try expectEqual(
            apiRequests.map { $0.value(forHTTPHeaderField: "Authorization") },
            ["Bearer access-1", "Bearer access-2"]
        )
    }

    static func testSpotifyWebAPIHonorsRetryAfter() async throws {
        let session = URLProtocolStub.makeSession { request in
            if request.url?.host == "accounts.spotify.com" {
                return .json(#"{"access_token":"access-test","expires_in":3600,"scope":"streaming"}"#)
            }
            return HTTPStubResponse(statusCode: 429, headers: ["Retry-After": "3"])
        }
        defer { session.invalidateAndCancel() }

        let authorization = SpotifyAuthorizationService(
            configuration: try SpotifyConfiguration(clientID: "test-client"),
            tokenStore: FixedRefreshTokenStore(token: "refresh-test"),
            session: session
        )
        let client = SpotifyWebAPIClient(
            authorizationService: authorization,
            session: session,
            baseURL: URL(string: "https://api.test/v1")!
        )

        do {
            _ = try await client.currentPlayback()
            throw TestFailure(message: "Expected a rate limit error", file: #file, line: #line)
        } catch let error as SpotifyWebAPIError {
            try expectEqual(error, .rateLimited(retryAfter: 3))
        }
    }

    static func testMusicBrainzEnrichmentUsesISRC() async throws {
        let recorder = HTTPRequestRecorder()
        let session = URLProtocolStub.makeSession { request in
            recorder.append(request)
            return .json(#"""
            {
              "recordings":[{
                "title":"Canonical Track",
                "length":181000,
                "artist-credit":[
                  {"name":"Canonical Artist","joinphrase":" feat. "},
                  {"name":"Guest","joinphrase":""}
                ],
                "releases":[{"title":"Canonical Album"}]
              }]
            }
            """#)
        }
        defer { session.invalidateAndCancel() }

        let client = MusicBrainzMetadataClient(
            session: session,
            baseURL: URL(string: "https://music.test")!,
            minimumRequestInterval: 0
        )
        let original = PlaybackTrack(
            title: "Localized Track",
            artist: "Localized Artist",
            album: "Spotify Album",
            duration: 180,
            sourceID: "track-1",
            isrc: "US-RC1-76-07839"
        )
        let enriched = try require(
            try await client.enrichedTrack(for: original),
            "ISRC should resolve metadata"
        )

        try expectEqual(enriched.title, "Canonical Track")
        try expectEqual(enriched.artist, "Canonical Artist feat. Guest")
        try expectEqual(enriched.album, "Spotify Album")
        try expectEqual(enriched.duration, 180)
        let request = try require(recorder.requests.first, "MusicBrainz request should be recorded")
        let components = try require(
            request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) },
            "MusicBrainz URL should be parseable"
        )
        try expectEqual(queryValue("query", in: components), "isrc:USRC17607839")
        try expectEqual(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("LyricX/"), true)
    }

    static func testLRCLIBRetriesWithNormalizedSpotifyMetadata() async throws {
        let recorder = HTTPRequestRecorder()
        let session = URLProtocolStub.makeSession { request in
            recorder.append(request)
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            if components.path == "/api/get" {
                return HTTPStubResponse(statusCode: 404)
            }
            let title = queryValue("track_name", in: components)
            let artist = queryValue("artist_name", in: components)
            if title == "Song", artist == "Artist" {
                return .json(#"[{"trackName":"Song","artistName":"Artist","albumName":"Album","duration":200,"syncedLyrics":"[00:01.00]Found"}]"#)
            }
            return .json("[]")
        }
        defer { session.invalidateAndCancel() }

        let client = LRCLIBClient(baseURL: URL(string: "https://lyrics.test")!, session: session)
        let track = PlaybackTrack(
            title: "Song (feat. Guest)",
            artist: "Artist, Guest",
            album: "Album",
            duration: 200
        )

        let lyrics = try await client.fetchSyncedLyrics(for: track)
        try expectEqual(lyrics, "[00:01.00]Found")
        try expectEqual(recorder.requests.filter { $0.url?.path == "/api/search" }.count, 2)
    }

    static func testLRCLIBRejectsUnrelatedArtist() async throws {
        let session = URLProtocolStub.makeSession { request in
            if request.url?.path == "/api/get" {
                return HTTPStubResponse(statusCode: 404)
            }
            return .json(#"[{"trackName":"Song","artistName":"Wrong Artist","syncedLyrics":"[00:01.00]Wrong"}]"#)
        }
        defer { session.invalidateAndCancel() }

        let client = LRCLIBClient(baseURL: URL(string: "https://lyrics.test")!, session: session)
        let lyrics = try await client.fetchSyncedLyrics(
            for: PlaybackTrack(title: "Song", artist: "Expected Artist")
        )

        try expectNil(lyrics)
    }

    static func testLRCLIBRejectsWrongVersionDuration() async throws {
        let session = URLProtocolStub.makeSession { request in
            if request.url?.path == "/api/get" {
                return HTTPStubResponse(statusCode: 404)
            }
            return .json(#"[{"trackName":"Song","artistName":"Artist","duration":240,"syncedLyrics":"[00:01.00]Wrong version"}]"#)
        }
        defer { session.invalidateAndCancel() }

        let client = LRCLIBClient(baseURL: URL(string: "https://lyrics.test")!, session: session)
        let lyrics = try await client.fetchSyncedLyrics(
            for: PlaybackTrack(title: "Song", artist: "Artist", duration: 200)
        )

        try expectNil(lyrics)
    }

    static func testLyricsRepositoryRetriesCanonicalMetadata() async throws {
        let session = URLProtocolStub.makeSession { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let title = queryValue("track_name", in: components)
            if components.path == "/api/get", title == "Canonical Name" {
                return .json(#"{"trackName":"Canonical Name","artistName":"Canonical Artist","duration":210,"syncedLyrics":"[00:02.00]Recovered"}"#)
            }
            if components.path == "/api/get" {
                return HTTPStubResponse(statusCode: 404)
            }
            return .json("[]")
        }
        defer { session.invalidateAndCancel() }

        let original = PlaybackTrack(
            title: "Localized Name",
            artist: "Localized Artist",
            duration: 210,
            isrc: "USRC17607839"
        )
        let enriched = PlaybackTrack(
            title: "Canonical Name",
            artist: "Canonical Artist",
            duration: 210,
            isrc: original.isrc
        )
        let cache = LyricsCache(directory: temporaryDirectoryURL(name: "metadata-lyrics-cache"))
        let repository = LyricsRepository(
            client: LRCLIBClient(baseURL: URL(string: "https://lyrics.test")!, session: session),
            cache: cache,
            metadataProvider: FixedMetadataProvider(track: enriched)
        )

        let timeline = try require(
            await repository.refreshTimeline(for: original),
            "Enriched metadata should recover lyrics"
        )
        try expectEqual(timeline.lines.first?.text, "Recovered")
        try expectEqual(cache.cachedLyrics(for: original), "[00:02.00]Recovered")
    }
}

private struct HTTPStubResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let data: Data

    init(statusCode: Int, headers: [String: String] = [:], data: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }

    static func json(_ value: String, statusCode: Int = 200) -> HTTPStubResponse {
        HTTPStubResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            data: Data(value.utf8)
        )
    }
}

private enum URLProtocolStub {
    typealias Handler = @Sendable (URLRequest) throws -> HTTPStubResponse

    static func makeSession(handler: @escaping Handler) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HandlerURLProtocol.self]
        HandlerURLProtocol.install(handler)
        return URLSession(configuration: configuration)
    }
}

private final class HandlerURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: URLProtocolStub.Handler?

    static func install(_ handler: @escaping URLProtocolStub.Handler) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self.handler
        Self.lock.unlock()
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let result = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: result.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: result.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !result.data.isEmpty {
                client?.urlProtocol(self, didLoad: result.data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private struct RecordedHTTPRequest: @unchecked Sendable {
    let request: URLRequest
    let body: Data?

    var url: URL? { request.url }
    var httpMethod: String? { request.httpMethod }

    func value(forHTTPHeaderField field: String) -> String? {
        request.value(forHTTPHeaderField: field)
    }
}

private final class HTTPRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequests: [RecordedHTTPRequest] = []

    var requests: [RecordedHTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    func append(_ request: URLRequest) {
        let recordedRequest = RecordedHTTPRequest(
            request: request,
            body: request.httpBody ?? Self.readBodyStream(request.httpBodyStream)
        )
        lock.lock()
        recordedRequests.append(recordedRequest)
        lock.unlock()
    }

    private static func readBodyStream(_ stream: InputStream?) -> Data? {
        guard let stream else {
            return nil
        }
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else {
                break
            }
            data.append(buffer, count: count)
        }
        return data.isEmpty ? nil : data
    }
}

private final class HTTPResponseGate: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)

    func wait() {
        semaphore.wait()
    }

    func open() {
        semaphore.signal()
    }
}

private struct FixedRefreshTokenStore: SpotifyRefreshTokenStore {
    let token: String

    func load() throws -> String? { token }
    func save(_ refreshToken: String) throws {}
    func delete() throws {}
}

private struct FixedMetadataProvider: TrackMetadataEnriching {
    let track: PlaybackTrack

    func enrichedTrack(for track: PlaybackTrack) async throws -> PlaybackTrack? {
        self.track
    }
}
