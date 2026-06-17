import AppKit
import Foundation

final class MenuBarTextMetrics {
    static let viewportWidth: CGFloat = 220
    static let fontSize: CGFloat = 13

    private let font: NSFont
    private let cacheLimit = 256
    private var widths: [String: CGFloat] = [:]

    init(fontSize: CGFloat = MenuBarTextMetrics.fontSize, fontWeight: NSFont.Weight = .medium) {
        font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
    }

    func width(for text: String) -> CGFloat {
        if let width = widths[text] {
            return width
        }

        if widths.count >= cacheLimit {
            widths.removeAll(keepingCapacity: true)
        }

        let width = (text as NSString).size(withAttributes: [.font: font]).width
        widths[text] = width
        return width
    }
}
