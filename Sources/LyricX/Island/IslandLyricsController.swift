import AppKit
import LyricXCore
import SwiftUI

@MainActor
final class IslandLyricsController {
    private let model: AppModel
    private let openSettings: () -> Void
    private var panel: NSPanel?
    private var hostingController: NSHostingController<IslandLyricsView>?
    private var timer: Timer?
    private var lastFrameRate: MenuBarAnimationFrameRate?
    private var displayState = IslandLyricsDisplayState.collapsed

    init(model: AppModel, openSettings: @escaping () -> Void) {
        self.model = model
        self.openSettings = openSettings
        restartTimer()
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

        guard model.showsIslandLyrics else {
            panel?.orderOut(nil)
            displayState = .collapsed
            return
        }

        showOrUpdatePanel(date: date)
    }

    private func showOrUpdatePanel(date: Date) {
        let panel = panel ?? makePanel(date: date)
        self.panel = panel

        hostingController?.rootView = islandLyricsView(date: date)
        applyPanelBehavior(panel)
        updateFrame(for: panel, date: date, animated: panel.isVisible)
        panel.orderFrontRegardless()
    }

    private func makePanel(date: Date) -> NSPanel {
        let hostingController = NSHostingController(rootView: islandLyricsView(date: date))
        let panel = NSPanel(
            contentRect: frame(for: date),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.title = "LyricX Island Lyrics"
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = hostingController
        applyPanelBehavior(panel)

        self.hostingController = hostingController
        return panel
    }

    private func islandLyricsView(date: Date) -> IslandLyricsView {
        IslandLyricsView(
            presentation: model.islandLyricsPresentation(at: date),
            isExpanded: displayState == .expanded,
            onToggleExpanded: { [weak self] in
                MainActor.assumeIsolated {
                    self?.toggleExpanded(date: Date())
                }
            },
            onHoverChanged: { [weak self] isHovering in
                MainActor.assumeIsolated {
                    self?.setHovering(isHovering, date: Date())
                }
            },
            onClose: { [weak self] in
                MainActor.assumeIsolated {
                    self?.model.showsIslandLyrics = false
                }
            },
            onToggleClickThrough: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else {
                        return
                    }
                    self.model.islandLyricsClickThrough.toggle()
                }
            },
            onOpenSettings: { [weak self] in
                MainActor.assumeIsolated {
                    self?.openSettings()
                }
            }
        )
    }

    private func toggleExpanded(date: Date) {
        setDisplayState(displayState == .expanded ? .collapsed : .expanded, date: date)
    }

    private func setHovering(_ isHovering: Bool, date: Date) {
        guard model.islandLyricsAutoExpandOnHover else {
            return
        }

        setDisplayState(isHovering ? .expanded : .collapsed, date: date)
    }

    private func setDisplayState(_ state: IslandLyricsDisplayState, date: Date) {
        guard displayState != state else {
            return
        }

        displayState = state
        guard let panel else {
            return
        }

        hostingController?.rootView = islandLyricsView(date: date)
        updateFrame(for: panel, date: date, animated: panel.isVisible)
    }

    private func applyPanelBehavior(_ panel: NSPanel) {
        panel.ignoresMouseEvents = model.islandLyricsClickThrough
    }

    private func updateFrame(for panel: NSPanel, date: Date, animated: Bool) {
        let targetFrame = frame(for: date)
        guard panel.frame != targetFrame else {
            return
        }

        panel.setFrame(targetFrame, display: true, animate: animated)
    }

    private func frame(for date: Date) -> NSRect {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let layoutFrame = IslandLyricsLayout.frame(
            in: IslandLyricsLayout.ScreenFrame(
                x: visibleFrame.origin.x,
                y: visibleFrame.origin.y,
                width: visibleFrame.width,
                height: visibleFrame.height
            ),
            state: displayState,
            preferredContentWidth: preferredContentWidth(for: date),
            topInset: 6
        )

        return NSRect(
            x: layoutFrame.x,
            y: layoutFrame.y,
            width: layoutFrame.width,
            height: layoutFrame.height
        )
    }

    private func preferredContentWidth(for date: Date) -> Double {
        let presentation = model.islandLyricsPresentation(at: date)
        let currentWidth = Double(presentation.currentText.count * 8 + 72)
        let nextWidth = Double((presentation.nextText?.count ?? 0) * 7 + 72)
        return max(currentWidth, nextWidth)
    }
}
