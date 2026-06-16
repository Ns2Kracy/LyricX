import Foundation

enum MenuBarTextBehavior: Equatable {
    case staticText
    case marquee
}

struct MenuBarPresentation: Equatable {
    let text: String
    let accessibilityText: String
    let symbol: String?
    let behavior: MenuBarTextBehavior
}
