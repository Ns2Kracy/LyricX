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
            .padding(14)
            .frame(width: 420, height: 190)
    }

    private func boolBinding(_ keyPath: ReferenceWritableKeyPath<AppModel, Bool>) -> Binding<Bool> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { model[keyPath: keyPath] = $0 }
        )
    }

    private var nowPlayingPanel: some View {
        HStack(alignment: .top, spacing: 14) {
            ArtworkView(
                artwork: model.artwork,
                fallbackTitle: model.playback.track?.album ?? "LyricX",
                size: 162
            )

            VStack(alignment: .leading, spacing: 10) {
                headerBlock
                lyricContextBlock
                Spacer(minLength: 0)
                progressBlock
                playbackToolbar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.playback.track?.title ?? "No Spotify Track")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(model.playback.track?.artist ?? model.playback.message ?? "Waiting for Spotify")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
            utilityMenu
        }
    }

    private var lyricContextBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentLyricText)
                .font(.callout.weight(.medium))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(nextLyricText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .topLeading)
    }

    private var playbackToolbar: some View {
        HStack(spacing: 8) {
            Button {
                model.previousTrack()
            } label: {
                Label("Previous Track", systemImage: "backward.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .disabled(!canControlPlayback)
            .help("Previous Track")

            Button {
                model.playPause()
            } label: {
                Label(playPauseTitle, systemImage: playPauseIcon)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .disabled(!canControlPlayback)
            .help(playPauseTitle)

            Button {
                model.nextTrack()
            } label: {
                Label("Next Track", systemImage: "forward.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .disabled(!canControlPlayback)
            .help("Next Track")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    private var progressBlock: some View {
        VStack(spacing: 5) {
            ProgressView(value: progressValue)
                .progressViewStyle(.linear)
                .controlSize(.mini)

            HStack {
                Text(formatTime(model.playback.position))
                Spacer()
                Text(remainingTimeText)
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundStyle(.tertiary)
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

    private var currentLyricText: String {
        if let text = model.currentLine?.text.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }

        return model.lyricsStatus
    }

    private var nextLyricText: String {
        if let text = model.nextLine?.text.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }

        return model.trackSummary
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
