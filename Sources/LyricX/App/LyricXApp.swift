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
            TimelineView(.periodic(
                from: Date(timeIntervalSinceReferenceDate: 0),
                by: container.model.menuBarFrameRate.frameInterval
            )) { context in
                MenuBarLabelView(
                    presentation: container.model.menuBarPresentation(at: context.date),
                    date: context.date
                )
            }
        }
        .menuBarExtraStyle(.window)
    }
}
