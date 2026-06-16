import AppKit
import SwiftUI

@main
@MainActor
struct LyricXApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup("LyricX", id: "main") {
            MainWindowView(model: container.model)
        }
        .defaultSize(width: 640, height: 460)

        MenuBarExtra {
            MenuBarContentView(model: container.model)
        } label: {
            MenuBarLabelView(presentation: container.model.menuBarPresentation())
        }
        .menuBarExtraStyle(.window)
    }
}
