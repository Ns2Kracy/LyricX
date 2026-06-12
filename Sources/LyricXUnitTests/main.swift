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
        try testLRCLIBLookupURLEncodesTrackQuery()
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

    private static func testLRCLIBLookupURLEncodesTrackQuery() throws {
        let client = LRCLIBClient(baseURL: URL(string: "https://example.test")!)
        let track = PlaybackTrack(
            title: "Sweet / Song",
            artist: "Artist & Friend",
            album: "Album Name",
            duration: 123.4
        )
        let url = client.lookupURL(for: track)
        let components = try require(URLComponents(url: url, resolvingAgainstBaseURL: false), "URL should be parseable")

        try expectEqual(components.scheme, "https")
        try expectEqual(components.host, "example.test")
        try expectEqual(components.path, "/api/get")
        try expectEqual(queryValue("track_name", in: components), "Sweet / Song")
        try expectEqual(queryValue("artist_name", in: components), "Artist & Friend")
        try expectEqual(queryValue("album_name", in: components), "Album Name")
        try expectEqual(queryValue("duration", in: components), "123")
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

    private static func require<T>(_ value: T?, _ message: String, file: StaticString = #file, line: UInt = #line) throws -> T {
        guard let value else {
            throw TestFailure(message: message, file: String(describing: file), line: line)
        }
        return value
    }

    private static func queryValue(_ name: String, in components: URLComponents) -> String? {
        components.queryItems?.first { $0.name == name }?.value
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
