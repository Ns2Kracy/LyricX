import AppKit
import Observation
import SwiftUI

@MainActor
final class FloatingLyricsController {
    private let model: AppModel
    private let panel: FloatingLyricsPanel
    private let hostingView: NSHostingView<FloatingLyricsView>

    init(model: AppModel) {
        self.model = model
        self.panel = FloatingLyricsPanel()
        self.hostingView = NSHostingView(rootView: FloatingLyricsView(model: model))

        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        observeModel()
    }

    private func observeModel() {
        withObservationTracking {
            applyPanelState()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeModel()
            }
        }
    }

    private func applyPanelState() {
        panel.ignoresMouseEvents = model.isClickThroughEnabled
        panel.isMovableByWindowBackground = !model.isFloatingPanelLocked && !model.isClickThroughEnabled

        if model.isLyricsVisible {
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        } else {
            panel.orderOut(nil)
        }
    }
}
