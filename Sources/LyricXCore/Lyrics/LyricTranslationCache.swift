import Foundation

public struct LyricTranslationCache: Sendable {
    public let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()
    }

    public func cachedTimeline(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) -> LyricTranslationTimeline? {
        let url = fileURL(for: track, sourceTimeline: sourceTimeline, targetLanguage: targetLanguage, includeRomaji: includeRomaji)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(LyricTranslationTimeline.self, from: data)
    }

    public func store(
        _ timeline: LyricTranslationTimeline,
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        includeRomaji: Bool
    ) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(timeline)
            try data.write(
                to: fileURL(
                    for: track,
                    sourceTimeline: sourceTimeline,
                    targetLanguage: timeline.targetLanguage,
                    includeRomaji: includeRomaji
                ),
                options: .atomic
            )
        } catch {
            // Cache writes are best-effort; source lyrics must not depend on disk access.
        }
    }

    public func fileURL(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) -> URL {
        directory
            .appendingPathComponent(cacheKey(for: track, sourceTimeline: sourceTimeline, targetLanguage: targetLanguage, includeRomaji: includeRomaji))
            .appendingPathExtension("json")
    }

    private func cacheKey(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) -> String {
        [
            track.artist,
            track.title,
            track.album ?? "",
            track.duration.map { String(Int($0.rounded())) } ?? "",
            targetLanguage.rawValue,
            includeRomaji ? "romaji" : "no-romaji",
            sourceFingerprint(sourceTimeline)
        ]
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

    private func sourceFingerprint(_ timeline: LyricTimeline) -> String {
        var hasher = DeterministicFingerprint()
        for line in timeline.lines {
            hasher.append(line.time.bitPattern)
            hasher.append(line.text)
            hasher.append(line.id)
        }
        return String(hasher.value, radix: 16)
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("LyricX/LyricTranslations", isDirectory: true)
    }
}

private struct DeterministicFingerprint {
    private(set) var value: UInt64 = 0xcbf29ce484222325

    mutating func append(_ string: String) {
        append(UInt64(string.unicodeScalars.count))
        for scalar in string.unicodeScalars {
            append(UInt64(scalar.value))
        }
    }

    mutating func append(_ number: UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            value ^= (number >> UInt64(shift)) & 0xff
            value = value &* 0x00000100000001b3
        }
    }
}
