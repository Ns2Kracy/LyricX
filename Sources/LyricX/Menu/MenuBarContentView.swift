import AppKit
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    let model: AppModel
    let openMainWindow: () -> Void

    private let elapsedTimeColumnWidth: CGFloat = 30
    private let remainingTimeColumnWidth: CGFloat = 36

    var body: some View {
        nowPlayingPanel
    }

    private func boolBinding(_ keyPath: ReferenceWritableKeyPath<AppModel, Bool>) -> Binding<Bool> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { model[keyPath: keyPath] = $0 }
        )
    }

    private var nowPlayingPanel: some View {
        VStack(spacing: 0) {
            headerBlock
            Spacer(minLength: 18)
            progressBlock
            Spacer(minLength: 14)
            playbackToolbar
        }
        .padding(18)
        .frame(width: 356, height: 232)
    }

    private var headerBlock: some View {
        HStack(alignment: .center, spacing: 16) {
            ArtworkView(
                artwork: model.artwork,
                fallbackTitle: model.playback.track?.album ?? "LyricX",
                size: 88
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(model.playback.track?.title ?? "No Spotify Track")
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(model.playback.track?.artist ?? model.playback.message ?? "Waiting for Spotify")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            utilityMenu
                .frame(width: 24, height: 88, alignment: .topTrailing)
        }
    }

    private var playbackToolbar: some View {
        HStack(spacing: 22) {
            transportButton("Previous Track", systemImage: "backward.fill") {
                model.previousTrack()
            }

            Button {
                model.playPause()
            } label: {
                Image(systemName: playPauseIcon)
                    .font(.system(size: 17, weight: .semibold))
            }
            .disabled(!canControlPlayback)
            .help(playPauseTitle)
            .accessibilityLabel(playPauseTitle)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)

            transportButton("Next Track", systemImage: "forward.fill") {
                model.nextTrack()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func transportButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
        }
        .disabled(!canControlPlayback)
        .help(title)
        .accessibilityLabel(title)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }

    private var progressBlock: some View {
        VStack(spacing: 4) {
            ProgressView(value: progressValue)
                .progressViewStyle(.linear)
                .controlSize(.small)

            HStack {
                Text(formatTime(model.playback.position))
                    .frame(width: elapsedTimeColumnWidth, alignment: .trailing)

                Spacer()

                Text(remainingTimeText)
                    .frame(width: remainingTimeColumnWidth, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }

    private var utilityMenu: some View {
        Menu {
            Button {
                openMainWindow()
            } label: {
                Label("Open LyricX", systemImage: "rectangle.on.rectangle")
            }

            Button {
                model.refreshLyrics()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Divider()

            Toggle(isOn: boolBinding(\.isLyricsVisible)) {
                Label("Show Lyrics", systemImage: "text.quote")
            }

            Toggle(isOn: boolBinding(\.showsTrackWhenLyricsMissing)) {
                Label("Show Track Fallback", systemImage: "music.note.list")
            }


            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit LyricX", systemImage: "power")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.semibold))
                .frame(width: 18, height: 18)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
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

    private var progressValue: Double {
        guard let duration = model.playback.track?.duration, duration > 0 else {
            return 0
        }

        return min(max(model.playback.position / duration, 0), 1)
    }

    private var remainingTimeText: String {
        guard let duration = model.playback.track?.duration else {
            return "--:--"
        }

        return "-\(formatTime(max(duration - model.playback.position, 0)))"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = max(Int(time), 0)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
