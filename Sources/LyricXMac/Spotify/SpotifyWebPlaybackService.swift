import Foundation
@preconcurrency import WebKit

public enum SpotifyWebPlaybackStatus: Equatable, Sendable {
    case idle
    case loading
    case ready(deviceID: String)
    case offline
    case failed(String)

    public var deviceID: String? {
        guard case .ready(let deviceID) = self else {
            return nil
        }
        return deviceID
    }

    public var title: String {
        switch self {
        case .idle:
            return "Not started"
        case .loading:
            return "Starting..."
        case .ready:
            return "Ready"
        case .offline:
            return "Offline"
        case .failed:
            return "Unavailable"
        }
    }

    public var detail: String? {
        guard case .failed(let message) = self else {
            return nil
        }
        return message
    }
}

public struct SpotifyWebPlaybackTrack: Equatable, Sendable {
    public let id: String?
    public let uri: String?
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: TimeInterval?
    public let artworkURL: URL?

    public init(
        id: String?,
        uri: String?,
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval?,
        artworkURL: URL?
    ) {
        self.id = id
        self.uri = uri
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
    }
}

public struct SpotifyWebPlaybackState: Equatable, Sendable {
    public let isPaused: Bool
    public let position: TimeInterval
    public let track: SpotifyWebPlaybackTrack?

    public init(isPaused: Bool, position: TimeInterval, track: SpotifyWebPlaybackTrack?) {
        self.isPaused = isPaused
        self.position = position
        self.track = track
    }
}

public enum SpotifyWebPlaybackEvent: Equatable, Sendable {
    case ready(deviceID: String)
    case offline
    case stateChanged(SpotifyWebPlaybackState?)
    case autoplayFailed
    case failed(String)
}

@MainActor
public final class SpotifyWebPlaybackService: NSObject {
    public let playerView: WKWebView
    public private(set) var status: SpotifyWebPlaybackStatus = .idle
    public var onEvent: ((SpotifyWebPlaybackEvent) -> Void)?

    private let authorizationService: SpotifyAuthorizationService
    private let messageProxy: SpotifyWebPlaybackMessageProxy

    public init(authorizationService: SpotifyAuthorizationService) {
        self.authorizationService = authorizationService

        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = false

        let messageProxy = SpotifyWebPlaybackMessageProxy()
        configuration.userContentController.add(messageProxy, name: "spotifyToken")
        configuration.userContentController.add(messageProxy, name: "spotifyEvent")
        self.messageProxy = messageProxy
        self.playerView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        messageProxy.delegate = self
    }

    public func start() {
        switch status {
        case .idle, .failed:
            status = .loading
            playerView.loadHTMLString(Self.playerHTML, baseURL: URL(string: "https://sdk.scdn.co"))
        case .offline:
            status = .loading
            Task { [weak self] in
                do {
                    try await self?.command("connect")
                } catch {
                    self?.status = .failed(error.localizedDescription)
                    self?.onEvent?(.failed(error.localizedDescription))
                }
            }
        case .loading, .ready:
            break
        }
    }

    public func disconnect() async {
        try? await command("disconnect")
        status = .idle
    }

    public func activateElement() async throws {
        try await command("activate")
    }

    public func playPause() async throws {
        try await command("togglePlay")
    }

    public func nextTrack() async throws {
        try await command("nextTrack")
    }

    public func previousTrack() async throws {
        try await command("previousTrack")
    }

    private func command(_ name: String) async throws {
        _ = try await playerView.callAsyncJavaScript(
            "return await window.lyricXCommand(command);",
            arguments: ["command": name],
            in: nil,
            contentWorld: .page
        )
    }

    private func deliverToken(requestID: String) {
        Task { [weak self, authorizationService] in
            do {
                let token = try await authorizationService.accessToken()
                try await self?.sendToken(requestID: requestID, token: token.value, error: nil)
            } catch {
                try? await self?.sendToken(
                    requestID: requestID,
                    token: nil,
                    error: error.localizedDescription
                )
            }
        }
    }

    private func sendToken(requestID: String, token: String?, error: String?) async throws {
        _ = try await playerView.callAsyncJavaScript(
            "window.lyricXReceiveToken(requestID, token, errorMessage);",
            arguments: [
                "requestID": requestID,
                "token": token ?? NSNull(),
                "errorMessage": error ?? NSNull()
            ],
            in: nil,
            contentWorld: .page
        )
    }

    private func receiveEvent(_ body: Any) {
        guard let payload = body as? [String: Any], let type = payload["type"] as? String else {
            return
        }

        let event: SpotifyWebPlaybackEvent
        switch type {
        case "ready":
            guard let deviceID = payload["deviceID"] as? String, !deviceID.isEmpty else {
                return
            }
            status = .ready(deviceID: deviceID)
            event = .ready(deviceID: deviceID)
        case "offline":
            status = .offline
            event = .offline
        case "state":
            event = .stateChanged(Self.playbackState(from: payload["state"]))
        case "autoplayFailed":
            event = .autoplayFailed
        case "warning":
            let message = (payload["message"] as? String) ?? "Spotify playback failed"
            event = .failed(message)
        case "error":
            let message = (payload["message"] as? String) ?? "Spotify Web Playback failed"
            status = .failed(message)
            event = .failed(message)
        default:
            return
        }
        onEvent?(event)
    }

    private static func playbackState(from value: Any?) -> SpotifyWebPlaybackState? {
        guard let state = value as? [String: Any] else {
            return nil
        }
        let trackPayload = state["track"] as? [String: Any]
        let durationMS = number(trackPayload?["durationMS"])
        let track = trackPayload.flatMap { payload -> SpotifyWebPlaybackTrack? in
            guard let title = payload["title"] as? String, !title.isEmpty else {
                return nil
            }
            return SpotifyWebPlaybackTrack(
                id: payload["id"] as? String,
                uri: payload["uri"] as? String,
                title: title,
                artist: (payload["artist"] as? String) ?? "",
                album: payload["album"] as? String,
                duration: durationMS.map { $0 / 1_000 },
                artworkURL: (payload["artworkURL"] as? String).flatMap(URL.init(string:))
            )
        }
        return SpotifyWebPlaybackState(
            isPaused: (state["paused"] as? Bool) ?? true,
            position: (number(state["positionMS"]) ?? 0) / 1_000,
            track: track
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return value as? Double
    }

    private static let playerHTML = #"""
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>html,body{margin:0;width:100%;height:100%;background:transparent;overflow:hidden}</style>
    </head>
    <body>
      <script>
        (() => {
          const callbacks = new Map();
          let player = null;

          const emit = (type, payload = {}) => {
            window.webkit.messageHandlers.spotifyEvent.postMessage({ type, ...payload });
          };

          const loadSDK = () => {
            const script = document.createElement('script');
            script.src = 'https://sdk.scdn.co/spotify-player.js';
            script.onerror = () => emit('error', { message: 'Unable to load Spotify Web Playback SDK' });
            document.head.appendChild(script);
          };

          window.lyricXReceiveToken = (requestID, token, errorMessage) => {
            const callback = callbacks.get(requestID);
            callbacks.delete(requestID);
            if (!callback) return;
            if (token) callback(token);
            else emit('error', { message: errorMessage || 'Spotify authorization failed' });
          };

          window.lyricXCommand = async (command) => {
            if (!player) throw new Error('Spotify Web Playback is not ready');
            switch (command) {
              case 'connect': return await player.connect();
              case 'disconnect': player.disconnect(); return true;
              case 'activate': await player.activateElement(); return true;
              case 'togglePlay': await player.togglePlay(); return true;
              case 'nextTrack': await player.nextTrack(); return true;
              case 'previousTrack': await player.previousTrack(); return true;
              default: throw new Error('Unknown Spotify Web Playback command');
            }
          };

          window.onSpotifyWebPlaybackSDKReady = () => {
            player = new Spotify.Player({
              name: 'LyricX',
              getOAuthToken: callback => {
                const requestID = crypto.randomUUID();
                callbacks.set(requestID, callback);
                window.webkit.messageHandlers.spotifyToken.postMessage({ requestID });
              },
              volume: 0.8,
              enableMediaSession: true
            });

            player.addListener('ready', ({ device_id }) => emit('ready', { deviceID: device_id }));
            player.addListener('not_ready', () => emit('offline'));
            player.addListener('autoplay_failed', () => emit('autoplayFailed'));
            for (const type of ['initialization_error', 'authentication_error', 'account_error']) {
              player.addListener(type, ({ message }) => emit('error', { message }));
            }
            player.addListener('playback_error', ({ message }) => emit('warning', { message }));
            player.addListener('player_state_changed', state => {
              if (!state) {
                emit('state', { state: null });
                return;
              }
              const current = state.track_window?.current_track;
              emit('state', {
                state: {
                  paused: state.paused,
                  positionMS: state.position,
                  track: current ? {
                    id: current.id,
                    uri: current.uri,
                    title: current.name,
                    artist: (current.artists || []).map(artist => artist.name).join(', '),
                    album: current.album?.name,
                    durationMS: current.duration_ms || state.duration,
                    artworkURL: current.album?.images?.[0]?.url || current.images?.[0]?.url
                  } : null
                }
              });
            });
            player.connect().catch(error => emit('error', { message: error.message }));
          };

          loadSDK();
          setTimeout(() => {
            if (!player) emit('error', { message: 'Spotify Web Playback SDK timed out' });
          }, 15000);
        })();
      </script>
    </body>
    </html>
    """#
}

private protocol SpotifyWebPlaybackMessageDelegate: AnyObject {
    @MainActor func receiveSpotifyMessage(name: String, body: Any)
}

private final class SpotifyWebPlaybackMessageProxy: NSObject, WKScriptMessageHandler {
    weak var delegate: SpotifyWebPlaybackMessageDelegate?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.receiveSpotifyMessage(name: message.name, body: message.body)
    }
}

extension SpotifyWebPlaybackService: SpotifyWebPlaybackMessageDelegate {
    fileprivate func receiveSpotifyMessage(name: String, body: Any) {
        switch name {
        case "spotifyToken":
            guard let payload = body as? [String: Any],
                  let requestID = payload["requestID"] as? String else {
                return
            }
            deliverToken(requestID: requestID)
        case "spotifyEvent":
            receiveEvent(body)
        default:
            break
        }
    }
}
