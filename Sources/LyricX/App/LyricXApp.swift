import AppKit
import SwiftUI

@main
@MainActor
struct LyricXApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra("LyricX", systemImage: container.model.menuBarSymbol) {
            MenuBarContentView(model: container.model)
        }
        .menuBarExtraStyle(.menu)
    }
}
