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

        WindowGroup("Settings", id: "settings") {
            SettingsView(model: container.model)
        }
        .defaultSize(width: 560, height: 540)

        MenuBarExtra {
            MenuBarContentView(model: container.model)
        } label: {
            MenuBarLabelView(presentation: container.model.menuBarPresentation())
        }
        .menuBarExtraStyle(.menu)
    }
}
