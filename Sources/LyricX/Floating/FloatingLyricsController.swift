import AppKit
import LyricXCore
import SwiftUI

@MainActor
final class FloatingLyricsController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var panel: NSPanel?
    private var hostingController: NSHostingController<FloatingLyricsView>?
    private var timer: Timer?
    private var lastFrameRate: MenuBarAnimationFrameRate?

    init(model: AppModel) {
        self.model = model
        super.init()
        restartTimer()
    }

    func windowDidMove(_ notification: Notification) {
        persistPanelFrameIfNeeded()
    }

    func windowDidResize(_ notification: Notification) {
        persistPanelFrameIfNeeded()
    }

    private func restartTimer() {
        timer?.invalidate()
        let frameRate = model.menuBarFrameRate
        lastFrameRate = frameRate

        let timer = Timer(timeInterval: frameRate.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick(date: Date())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick(date: Date) {
        if model.menuBarFrameRate != lastFrameRate {
            restartTimer()
        }

        guard model.showsFloatingLyrics else {
            panel?.orderOut(nil)
            return
        }

        showOrUpdatePanel(date: date)
    }

    private func showOrUpdatePanel(date: Date) {
        let panel = panel ?? makePanel(date: date)
        self.panel = panel

        hostingController?.rootView = floatingLyricsView(date: date)
        applyPanelBehavior(panel)
        panel.orderFrontRegardless()
    }

    private func makePanel(date: Date) -> NSPanel {
        let hostingController = NSHostingController(
            rootView: floatingLyricsView(date: date)
        )
        let panel = NSPanel(
            contentRect: restoredOrDefaultFrame(),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.title = "LyricX Floating Lyrics"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 360, height: 112)
        panel.maxSize = NSSize(width: 980, height: 260)
        panel.contentViewController = hostingController
        panel.delegate = self
        applyPanelBehavior(panel)

        self.hostingController = hostingController
        return panel
    }

    private func floatingLyricsView(date: Date) -> FloatingLyricsView {
        FloatingLyricsView(
            presentation: model.floatingLyricsPresentation(at: date),
            onClose: { [weak self] in
                MainActor.assumeIsolated {
                    self?.model.showsFloatingLyrics = false
                }
            }
        )
    }

    private func applyPanelBehavior(_ panel: NSPanel) {
        panel.isMovableByWindowBackground = !model.floatingLyricsLocked && !model.floatingLyricsClickThrough
        panel.ignoresMouseEvents = model.floatingLyricsClickThrough
    }

    private func persistPanelFrameIfNeeded() {
        guard let panel, !model.floatingLyricsClickThrough else {
            return
        }

        let frame = panel.frame
        model.updateFloatingLyricsWindowFrame(
            FloatingLyricsWindowFrame(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.width,
                height: frame.height
            )
        )
    }

    private func restoredOrDefaultFrame() -> NSRect {
        if let savedFrame = model.settings.floatingLyricsWindowFrame {
            let rect = NSRect(x: savedFrame.x, y: savedFrame.y, width: savedFrame.width, height: savedFrame.height)
            if rect.width > 0, rect.height > 0, intersectsVisibleScreen(rect) {
                return rect
            }
        }

        let size = NSSize(width: 720, height: 112)
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - size.height - 56,
            width: size.width,
            height: size.height
        )
    }

    private func intersectsVisibleScreen(_ rect: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(rect)
        }
    }
}
