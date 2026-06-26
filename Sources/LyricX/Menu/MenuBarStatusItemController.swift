import AppKit
import LyricXCore
import SwiftUI

@MainActor
final class MenuBarStatusItemController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let openMainWindow: () -> Void
    private let statusItem: NSStatusItem
    private let statusView = MenuBarStatusItemView(frame: .zero)
    private let popover = NSPopover()
    private var timer: Timer?
    private var outsideClickMonitor: Any?
    private var lastFrameRate: MenuBarAnimationFrameRate?
    private var lastPresentation: MenuBarPresentation?

    init(model: AppModel, openMainWindow: @escaping () -> Void) {
        self.model = model
        self.openMainWindow = openMainWindow
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.autosaveName = "com.ns2kracy.LyricX.menuBarLyrics"

        statusView.target = self
        statusView.action = #selector(togglePopover(_:))
        if let button = statusItem.button {
            button.title = ""
            button.image = nil
            button.target = self
            button.action = #selector(togglePopover(_:))
            statusView.frame = button.bounds
            statusView.autoresizingMask = [.width, .height]
            button.addSubview(statusView)
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 180)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(model: model) { [weak self] in
                self?.closePopoverAndOpenMainWindow()
            }
        )

        restartTimer()
        render(date: Date(), force: true)
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitor()
        render(date: Date(), force: true)
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: statusView.bounds, of: statusView, preferredEdge: .minY)
            startOutsideClickMonitor()
            render(date: Date(), force: true)
        }
    }

    private func closePopoverAndOpenMainWindow() {
        popover.performClose(nil)
        openMainWindow()
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else {
            return
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.popover.isShown else {
                    return
                }

                self.popover.performClose(nil)
            }
        }
    }

    private func stopOutsideClickMonitor() {
        guard let outsideClickMonitor else {
            return
        }

        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }

    private func restartTimer() {
        timer?.invalidate()
        let frameRate = model.menuBarFrameRate
        lastFrameRate = frameRate

        let timer = Timer(timeInterval: frameRate.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        if model.menuBarFrameRate != lastFrameRate {
            restartTimer()
        }

        render(date: Date(), force: false)
    }

    private func render(date: Date, force: Bool) {
        model.refreshLyricContext(at: date)
        let presentation = model.menuBarPresentation(at: date)
        let needsAnimation = presentation.behavior.isAnimated
        guard force || needsAnimation || presentation != lastPresentation else {
            return
        }

        statusView.update(presentation: presentation, date: date)
        statusItem.length = statusView.frame.width
        if let button = statusItem.button {
            statusView.frame = button.bounds
        }
        lastPresentation = presentation
    }
}

private extension MenuBarTextBehavior {
    var isAnimated: Bool {
        if case .continuousMarquee = self {
            return true
        }
        return false
    }
}
