import Foundation
import LyricXCore

@main
struct LyricXUnitTests {
    static func main() throws {
        try testParsesTimestampedLine()
        try testParsesMultipleTimestampsOnOneLine()
        try testIgnoresMetadataAndBlankLines()
        try testSortsParsedLinesByTime()
        try testTimelineReturnsNilBeforeFirstLine()
        try testTimelineReturnsCurrentLineAtAndBetweenTimestamps()
        try testTimelineReturnsNextLineAfterPosition()
        print("LyricXUnitTests passed")
    }

    private static func testParsesTimestampedLine() throws {
        let lines = LRCParser.parse("[00:12.34]First line")
        try expectEqual(lines, [LyricLine(time: 12.34, text: "First line")])
    }

    private static func testParsesMultipleTimestampsOnOneLine() throws {
        let lines = LRCParser.parse("[00:10.00][00:20.50]Chorus")
        try expectEqual(lines, [
            LyricLine(time: 10.0, text: "Chorus"),
            LyricLine(time: 20.5, text: "Chorus")
        ])
    }

    private static func testIgnoresMetadataAndBlankLines() throws {
        let lrc = """
        [ar:Artist]

        [ti:Song]
        [00:01.00]Opening
        """
        try expectEqual(LRCParser.parse(lrc), [LyricLine(time: 1.0, text: "Opening")])
    }

    private static func testSortsParsedLinesByTime() throws {
        let lrc = """
        [00:30.00]Third
        [00:10.00]First
        [00:20.00]Second
        """
        try expectEqual(LRCParser.parse(lrc), [
            LyricLine(time: 10.0, text: "First"),
            LyricLine(time: 20.0, text: "Second"),
            LyricLine(time: 30.0, text: "Third")
        ])
    }

    private static func testTimelineReturnsNilBeforeFirstLine() throws {
        let timeline = LyricTimeline(lines: [LyricLine(time: 10.0, text: "First")])
        try expectNil(timeline.currentLine(at: 9.9))
    }

    private static func testTimelineReturnsCurrentLineAtAndBetweenTimestamps() throws {
        let timeline = LyricTimeline(lines: [
            LyricLine(time: 10.0, text: "First"),
            LyricLine(time: 20.0, text: "Second")
        ])

        try expectEqual(timeline.currentLine(at: 10.0), LyricLine(time: 10.0, text: "First"))
        try expectEqual(timeline.currentLine(at: 19.9), LyricLine(time: 10.0, text: "First"))
        try expectEqual(timeline.currentLine(at: 20.0), LyricLine(time: 20.0, text: "Second"))
    }

    private static func testTimelineReturnsNextLineAfterPosition() throws {
        let timeline = LyricTimeline(lines: [
            LyricLine(time: 10.0, text: "First"),
            LyricLine(time: 20.0, text: "Second")
        ])

        try expectEqual(timeline.nextLine(after: 10.0), LyricLine(time: 20.0, text: "Second"))
        try expectNil(timeline.nextLine(after: 20.0))
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) throws {
        guard actual == expected else {
            throw TestFailure(message: "Expected \(expected), got \(actual)", file: String(describing: file), line: line)
        }
    }

    private static func expectNil<T>(_ actual: T?, file: StaticString = #file, line: UInt = #line) throws {
        guard actual == nil else {
            throw TestFailure(message: "Expected nil, got \(String(describing: actual))", file: String(describing: file), line: line)
        }
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let message: String
    let file: String
    let line: UInt

    var description: String {
        "\(file):\(line): \(message)"
    }
}
