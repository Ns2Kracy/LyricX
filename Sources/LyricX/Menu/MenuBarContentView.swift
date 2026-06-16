import AppKit
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow

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

        Button {
            openWindow(id: "main")
        } label: {
            Label("Open LyricX", systemImage: "rectangle.on.rectangle")
        }

        Button {
            openWindow(id: "settings")
        } label: {
            Label("Settings", systemImage: "gearshape")
        }

        Divider()

        Button {
            model.previousTrack()
        } label: {
            Label("Previous Track", systemImage: "backward.fill")
        }
        .disabled(!canControlPlayback)

        Button {
            model.playPause()
        } label: {
            Label(playPauseTitle, systemImage: playPauseIcon)
        }
        .disabled(!canControlPlayback)

        Button {
            model.nextTrack()
        } label: {
            Label("Next Track", systemImage: "forward.fill")
        }
        .disabled(!canControlPlayback)

        Divider()

        Toggle(isOn: boolBinding(\.isLyricsVisible)) {
            Label("Show Lyrics in Menu Bar", systemImage: "text.quote")
        }

        Toggle(isOn: boolBinding(\.showsTrackWhenLyricsMissing)) {
            Label("Show Track When Missing", systemImage: "music.note.list")
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

    private var canControlPlayback: Bool {
        model.playback.state != .notRunning && model.playback.state != .unavailable
    }

    private var playPauseTitle: String {
        model.playback.isPlaying ? "Pause" : "Play"
    }

    private var playPauseIcon: String {
        model.playback.isPlaying ? "pause.fill" : "play.fill"
    }
}
