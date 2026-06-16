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
            MenuBarLabelView(presentation: container.model.menuBarPresentation())
        }
        .menuBarExtraStyle(.menu)
    }
}
