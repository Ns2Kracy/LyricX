import AppKit
import SwiftUI

@MainActor
final class MainWindowController {
    private let model: AppModel
    private var window: NSWindow?
    private var settingsWindow: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func showWindow() {
        let window = window ?? makeWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(rootView: MainWindowView(model: model) { [weak self] in
            self?.showSettings()
        })
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LyricX"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func makeSettingsWindow() -> NSWindow {
        let controller = NSHostingController(rootView: SettingsView(model: model))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
