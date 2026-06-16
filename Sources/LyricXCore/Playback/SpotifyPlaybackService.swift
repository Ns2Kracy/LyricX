import Foundation

public struct SpotifyPlaybackService: Sendable {
    private let runScript: @Sendable (String) throws -> String

    public init() {
        self.runScript = Self.defaultRunAppleScript
    }

    public init(runScript: @escaping @Sendable (String) throws -> String) {
        self.runScript = runScript
    }

    public func currentSnapshot() -> PlaybackSnapshot {
        do {
            return try Self.parse(output: runScript(Self.spotifyScript))
        } catch {
            return PlaybackSnapshot(state: .unavailable, message: error.localizedDescription)
        }
    }

    static func parse(output: String) -> PlaybackSnapshot {
        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        guard let stateLine = lines.first?.nilIfBlank else {
            return PlaybackSnapshot(state: .unavailable, message: "Spotify returned no playback state")
        }

        switch stateLine {
        case "not_running":
            return PlaybackSnapshot(state: .notRunning, message: "Spotify is not running")
        case "stopped":
            return PlaybackSnapshot(state: .stopped, message: "Spotify is stopped")
        case "playing", "paused":
            guard lines.count >= 6 else {
                return PlaybackSnapshot(state: .unavailable, message: "Spotify returned incomplete track data")
            }

            let rawDuration = TimeInterval(lines[4])
            let duration = rawDuration.map { $0 > 10_000 ? $0 / 1_000 : $0 }
            let position = TimeInterval(lines[5]) ?? 0
            let track = PlaybackTrack(
                title: lines[1],
                artist: lines[2],
                album: lines[3],
                duration: duration
            )
            return PlaybackSnapshot(
                state: stateLine == "playing" ? .playing : .paused,
                track: track,
                position: position
            )
        default:
            return PlaybackSnapshot(state: .unavailable, message: "Unsupported Spotify state: \(stateLine)")
        }
    }

    private static func defaultRunAppleScript(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        throw SpotifyPlaybackError.scriptFailed(errorOutput?.nilIfBlank ?? "osascript exited with status \(process.terminationStatus)")
    }

    private static let spotifyScript = """
    tell application "System Events"
        if not (exists process "Spotify") then
            return "not_running"
        end if
    end tell

    tell application "Spotify"
        set playbackState to player state as string
        if playbackState is "stopped" then
            return "stopped"
        end if

        set trackName to name of current track
        set artistName to artist of current track
        set albumName to album of current track
        set durationValue to duration of current track
        set positionValue to player position
        return playbackState & linefeed & trackName & linefeed & artistName & linefeed & albumName & linefeed & durationValue & linefeed & positionValue
    end tell
    """
}

extension SpotifyPlaybackService: PlayerService {
    public func playPause() {
        runCommand(.playPause)
    }

    public func nextTrack() {
        runCommand(.nextTrack)
    }

    public func previousTrack() {
        runCommand(.previousTrack)
    }

    private func runCommand(_ command: SpotifyPlayerCommand) {
        _ = try? runScript(command.appleScript)
    }
}

extension SpotifyPlaybackService: ArtworkProvider {
    public func artwork(for _: PlaybackTrack) async -> TrackArtwork? {
        nil
    }
}

enum SpotifyPlaybackError: LocalizedError {
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .scriptFailed(let message):
            message
        }
    }
}
