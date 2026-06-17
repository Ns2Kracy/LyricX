import Foundation

public enum MenuBarAnimationFrameRate: Int, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case fps15 = 15
    case fps30 = 30
    case fps60 = 60
    case fps120 = 120

    public var id: Int { rawValue }

    public var label: String {
        "\(rawValue) fps"
    }

    public var frameInterval: TimeInterval {
        1.0 / TimeInterval(rawValue)
    }

    public static let `default` = MenuBarAnimationFrameRate.fps30
}
