import Foundation

public enum LRCParser {
    public static func parse(_ source: String) -> [LyricLine] {
        source
            .split(whereSeparator: \.isNewline)
            .flatMap(parseLine)
            .sorted { lhs, rhs in
                if lhs.time == rhs.time {
                    lhs.text < rhs.text
                } else {
                    lhs.time < rhs.time
                }
            }
    }

    private static func parseLine(_ rawLine: Substring) -> [LyricLine] {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else {
            return []
        }

        var remainder = line[...]
        var timestamps: [TimeInterval] = []

        while remainder.first == "[", let endIndex = remainder.firstIndex(of: "]") {
            let tagStart = remainder.index(after: remainder.startIndex)
            let tag = String(remainder[tagStart..<endIndex])
            guard let timestamp = parseTimestamp(tag) else {
                break
            }

            timestamps.append(timestamp)
            remainder = remainder[remainder.index(after: endIndex)...]
        }

        let text = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !timestamps.isEmpty, !text.isEmpty else {
            return []
        }

        return timestamps.map { LyricLine(time: $0, text: text) }
    }

    private static func parseTimestamp(_ tag: String) -> TimeInterval? {
        let parts = tag.split(separator: ":")
        guard parts.count == 2 || parts.count == 3 else {
            return nil
        }

        let secondsPart = parts[parts.count - 1]
        guard let seconds = TimeInterval(secondsPart) else {
            return nil
        }

        if parts.count == 2 {
            guard let minutes = TimeInterval(parts[0]) else {
                return nil
            }
            return minutes * 60 + seconds
        }

        guard let hours = TimeInterval(parts[0]), let minutes = TimeInterval(parts[1]) else {
            return nil
        }
        return hours * 3600 + minutes * 60 + seconds
    }
}
