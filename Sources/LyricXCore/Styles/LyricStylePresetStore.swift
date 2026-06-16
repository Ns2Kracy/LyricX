import Foundation

public struct LyricStylePresetState: Codable, Equatable, Sendable {
    public var presets: [LyricStylePreset]
    public var activePresetID: UUID

    public init(presets: [LyricStylePreset], activePresetID: UUID) {
        self.presets = presets
        self.activePresetID = activePresetID
    }
}

public struct LyricStylePresetStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> LyricStylePresetState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Self.defaultState
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(LyricStylePresetState.self, from: data)
    }

    public func save(presets: [LyricStylePreset], activePresetID: UUID) throws {
        try save(LyricStylePresetState(presets: presets, activePresetID: activePresetID))
    }

    public func save(_ state: LyricStylePresetState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    public static var defaultState: LyricStylePresetState {
        LyricStylePresetState(
            presets: LyricStylePreset.defaults,
            activePresetID: LyricStylePreset.defaults[0].id
        )
    }
}
