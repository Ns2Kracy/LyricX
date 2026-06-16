import Foundation

public struct AppVersion: Comparable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    private var parts: [Int] {
        rawValue.split(separator: ".").map { part in
            let digits = part.prefix { $0.isNumber }
            return Int(digits) ?? 0
        }
    }

    private var comparableParts: [Int] {
        var values = parts
        while values.count > 1, values.last == 0 {
            values.removeLast()
        }
        return values
    }

    public init(_ rawValue: String) {
        self.rawValue = Self.normalized(rawValue)
    }

    public var description: String {
        rawValue
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.comparableParts == rhs.comparableParts
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let lhsParts = lhs.comparableParts
        let rhsParts = rhs.comparableParts
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let lhsValue = index < lhsParts.count ? lhsParts[index] : 0
            let rhsValue = index < rhsParts.count ? rhsParts[index] : 0

            if lhsValue != rhsValue {
                return lhsValue < rhsValue
            }
        }

        return false
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func normalized(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v") {
            trimmed.removeFirst()
        }
        return trimmed
    }
}

public struct AppUpdate: Equatable, Sendable {
    public let version: AppVersion
    public let pageURL: URL
    public let packageURL: URL?
    public let checksumURL: URL?

    public init(version: AppVersion, pageURL: URL, packageURL: URL?, checksumURL: URL?) {
        self.version = version
        self.pageURL = pageURL
        self.packageURL = packageURL
        self.checksumURL = checksumURL
    }
}

public protocol UpdateService: Sendable {
    func latestVersion() async throws -> AppUpdate?
}

public enum AppUpdateError: LocalizedError, Sendable {
    case requestFailed(Int)

    public var errorDescription: String? {
        switch self {
        case .requestFailed(let statusCode):
            "GitHub release request failed with status \(statusCode)"
        }
    }
}
