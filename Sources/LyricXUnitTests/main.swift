import Foundation
import LyricXCore

@main
struct LyricXUnitTests {
    static func main() throws {
        try testParsesTimestampedLine()
        print("LyricXUnitTests passed")
    }

    private static func testParsesTimestampedLine() throws {
        let lines = LRCParser.parse("[00:12.34]First line")
        try expectEqual(lines, [LyricLine(time: 12.34, text: "First line")])
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) throws {
        guard actual == expected else {
            throw TestFailure(message: "Expected \(expected), got \(actual)", file: String(describing: file), line: line)
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
