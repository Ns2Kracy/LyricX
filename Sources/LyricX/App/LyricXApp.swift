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
            TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 1.0 / 30.0)) { context in
                MenuBarLabelView(
                    presentation: container.model.menuBarPresentation(at: context.date),
                    date: context.date
                )
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
