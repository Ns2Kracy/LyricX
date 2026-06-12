import AppKit
import SwiftUI

@main
struct LyricXApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("LyricX", systemImage: model.menuBarSymbol) {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}
