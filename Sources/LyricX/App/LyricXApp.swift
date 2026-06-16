import AppKit
import SwiftUI

@main
@MainActor
struct LyricXApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: container.model)
        } label: {
            HStack(spacing: 4) {
                if container.model.shouldShowMenuBarIcon {
                    Image(systemName: container.model.menuBarSymbol)
                }
                Text(container.model.menuBarDisplayText)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .accessibilityLabel(container.model.menuBarText)
        }
        .menuBarExtraStyle(.menu)
    }
}
