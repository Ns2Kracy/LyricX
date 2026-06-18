public struct MenuBarClickFeedbackState: Equatable, Sendable {
    public private(set) var isVisible: Bool
    public private(set) var isPressed: Bool
    private var generation: Int

    public init(isVisible: Bool = false, isPressed: Bool = false, generation: Int = 0) {
        self.isVisible = isVisible
        self.isPressed = isPressed
        self.generation = generation
    }

    public mutating func press() -> Int {
        generation += 1
        isPressed = true
        isVisible = true
        return generation
    }

    public mutating func release() -> Int {
        generation += 1
        isPressed = false
        return generation
    }

    public mutating func expire(generation expectedGeneration: Int) {
        guard generation == expectedGeneration, !isPressed else {
            return
        }

        isVisible = false
    }
}
