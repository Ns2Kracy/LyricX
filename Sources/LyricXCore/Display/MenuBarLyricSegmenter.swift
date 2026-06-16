import Foundation

public struct MenuBarLyricSegmenter: Sendable {
    public let visibleCharacters: Int

    public init(visibleCharacters: Int) {
        self.visibleCharacters = max(1, visibleCharacters)
    }

    public func displayText(for currentLine: LyricLine, nextLine: LyricLine?, position: TimeInterval) -> String {
        let lineSegments = segments(for: currentLine.text)
        guard lineSegments.count > 1 else {
            return lineSegments.first ?? ""
        }

        let lineDuration = max((nextLine?.time ?? fallbackEndTime(for: currentLine, segmentCount: lineSegments.count)) - currentLine.time, 0.1)
        let elapsed = min(max(position - currentLine.time, 0), lineDuration.nextDown)
        let progress = elapsed / lineDuration
        let segmentIndex = min(Int(progress * Double(lineSegments.count)), lineSegments.count - 1)
        return lineSegments[segmentIndex]
    }

    public func segments(for text: String) -> [String] {
        let normalized = normalize(text)
        guard normalized.count > visibleCharacters else {
            return normalized.isEmpty ? [] : [normalized]
        }

        let words = normalized.split(separator: " ").map(String.init)
        guard !words.isEmpty else {
            return []
        }

        var result: [String] = []
        var current = ""

        for word in words {
            for piece in pieces(for: word) {
                if current.isEmpty {
                    current = piece
                } else if current.count + 1 + piece.count <= visibleCharacters {
                    current += " " + piece
                } else {
                    result.append(current)
                    current = piece
                }
            }
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }

    private func normalize(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private func pieces(for word: String) -> [String] {
        guard word.count > visibleCharacters else {
            return [word]
        }

        var pieces: [String] = []
        var index = word.startIndex
        while index < word.endIndex {
            let end = word.index(index, offsetBy: visibleCharacters, limitedBy: word.endIndex) ?? word.endIndex
            pieces.append(String(word[index..<end]))
            index = end
        }
        return pieces
    }

    private func fallbackEndTime(for line: LyricLine, segmentCount: Int) -> TimeInterval {
        line.time + TimeInterval(segmentCount) * 1.6
    }
}
