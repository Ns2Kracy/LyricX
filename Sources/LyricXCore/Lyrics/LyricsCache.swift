import Foundation

public struct LyricsCache: Sendable {
    public let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()
    }

    public func cachedLyrics(for track: PlaybackTrack) -> String? {
        try? String(contentsOf: fileURL(for: track), encoding: .utf8)
    }

    public func store(_ lyrics: String, for track: PlaybackTrack) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try lyrics.write(to: fileURL(for: track), atomically: true, encoding: .utf8)
        } catch {
            // Cache writes are best-effort; lyric display should not depend on disk access.
        }
    }

    public func fileURL(for track: PlaybackTrack) -> URL {
        directory.appendingPathComponent(cacheKey(for: track)).appendingPathExtension("lrc")
    }

    private func cacheKey(for track: PlaybackTrack) -> String {
        [track.artist, track.title, track.album ?? "", track.duration.map { String(Int($0.rounded())) } ?? ""]
            .joined(separator: "-")
            .lowercased()
            .unicodeScalars
            .map { scalar -> Character in
                CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
            }
            .reduce(into: "") { result, character in
                if character == "-", result.last == "-" {
                    return
                }
                result.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("LyricX/Lyrics", isDirectory: true)
    }
}
