import AppKit
import Foundation
import LyricXCore

final class MenuBarTextMetrics {
    private let cacheLimit = 256
    private var widths: [CacheKey: CGFloat] = [:]

    func width(for text: String, style: MenuBarStyle) -> CGFloat {
        let key = CacheKey(text: text, fontSize: style.fontSize, fontWeight: style.fontWeight)
        if let width = widths[key] {
            return width
        }

        if widths.count >= cacheLimit {
            widths.removeAll(keepingCapacity: true)
        }

        let font = NSFont.systemFont(ofSize: CGFloat(style.fontSize), weight: style.fontWeight.appKitWeight)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        widths[key] = width
        return width
    }

    private struct CacheKey: Hashable {
        let text: String
        let fontSize: Double
        let fontWeight: MenuBarFontWeight
    }
}

private extension MenuBarFontWeight {
    var appKitWeight: NSFont.Weight {
        switch self {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        }
    }
}
