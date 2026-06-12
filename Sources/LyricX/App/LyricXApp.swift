import AppKit
import SwiftUI

@main
struct LyricXApp: App {
    var body: some Scene {
        MenuBarExtra("LyricX", systemImage: "music.note") {
            Text("LyricX")

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
