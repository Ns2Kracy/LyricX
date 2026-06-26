import AppKit
import LyricXApp
import SwiftUI

@main
@MainActor
struct LyricXExecutableApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
