import AppKit
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.trackSummary)
                .font(.headline)
                .lineLimit(1)

            Text(model.lyricsStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 260, alignment: .leading)
        .padding(.vertical, 4)

        Divider()

        Toggle(isOn: boolBinding(\.isLyricsVisible)) {
            Label("Show Lyrics", systemImage: "text.quote")
        }

        Toggle(isOn: boolBinding(\.isFloatingPanelLocked)) {
            Label("Lock Position", systemImage: model.isFloatingPanelLocked ? "lock" : "lock.open")
        }

        Toggle(isOn: boolBinding(\.isClickThroughEnabled)) {
            Label("Click Through", systemImage: "cursorarrow.rays")
        }

        Button {
            model.refreshLyrics()
        } label: {
            Label("Refresh Lyrics", systemImage: "arrow.clockwise")
        }

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit LyricX", systemImage: "power")
        }
        .keyboardShortcut("q")
    }

    private func boolBinding(_ keyPath: ReferenceWritableKeyPath<AppModel, Bool>) -> Binding<Bool> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { model[keyPath: keyPath] = $0 }
        )
    }
}
