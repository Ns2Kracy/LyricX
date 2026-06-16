import LyricXCore
import SwiftUI

@MainActor
struct MainWindowView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            lyrics

            Divider()

            footer
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 420, idealHeight: 460)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            ArtworkView(artwork: model.artwork, fallbackTitle: model.playback.track?.album ?? "LyricX")

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Label(playbackStatus, systemImage: playbackStatusIcon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        model.refreshLyrics()
                    } label: {
                        Label("Refresh Lyrics", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .help("Refresh Lyrics")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.playback.track?.title ?? "No Spotify Track")
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)

                    Text(model.playback.track?.artist ?? model.playback.message ?? "Waiting for Spotify")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let album = model.playback.track?.album {
                        Text(album)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                playbackControls

                if let duration = model.playback.track?.duration {
                    Text("\(formatTime(model.playback.position)) / \(formatTime(duration))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
    }

    private var playbackControls: some View {
        HStack(spacing: 10) {
            Button {
                model.previousTrack()
            } label: {
                Label("Previous Track", systemImage: "backward.fill")
                    .labelStyle(.iconOnly)
            }
            .help("Previous Track")
            .accessibilityLabel("Previous Track")

            Button {
                model.playPause()
            } label: {
                Label(playPauseLabel, systemImage: playPauseIcon)
                    .labelStyle(.iconOnly)
            }
            .keyboardShortcut(.space, modifiers: [])
            .help(playPauseLabel)
            .accessibilityLabel(playPauseLabel)

            Button {
                model.nextTrack()
            } label: {
                Label("Next Track", systemImage: "forward.fill")
                    .labelStyle(.iconOnly)
            }
            .help("Next Track")
            .accessibilityLabel("Next Track")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(model.playback.state == .notRunning || model.playback.state == .unavailable)
    }

    private var lyrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lyrics")
                .font(.headline)

            LyricContextRow(label: "Previous", text: previousLyricText, prominence: .secondary)
            LyricContextRow(label: "Current", text: currentLyricText, prominence: .primary)
            LyricContextRow(label: "Next", text: model.nextLine?.text ?? "No next line", prominence: .secondary)
        }
        .padding(24)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Label(model.activeStylePreset.name, systemImage: "paintpalette")
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(model.updateStatus)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                model.checkForUpdates()
            } label: {
                Label("Check for Updates", systemImage: "arrow.down.circle")
            }
            .controlSize(.small)
            .help("Check for Updates")
        }
        .font(.caption)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var playbackStatus: String {
        switch model.playback.state {
        case .notRunning:
            "Spotify not running"
        case .stopped:
            "Spotify stopped"
        case .paused:
            "Paused"
        case .playing:
            "Playing"
        case .unavailable:
            "Spotify unavailable"
        }
    }

    private var playbackStatusIcon: String {
        switch model.playback.state {
        case .playing:
            "play.fill"
        case .paused:
            "pause.fill"
        case .stopped:
            "stop.fill"
        case .notRunning, .unavailable:
            "exclamationmark.circle"
        }
    }

    private var playPauseLabel: String {
        model.playback.isPlaying ? "Pause" : "Play"
    }

    private var playPauseIcon: String {
        model.playback.isPlaying ? "pause.fill" : "play.fill"
    }

    private var previousLyricText: String {
        guard let currentLine = model.currentLine else {
            return "No previous line"
        }
        return model.timeline?.lines.last { $0.time < currentLine.time }?.text ?? "No previous line"
    }

    private var currentLyricText: String {
        model.currentLine?.text ?? model.lyricsStatus
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = max(Int(time), 0)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct LyricContextRow: View {
    enum Prominence {
        case primary
        case secondary
    }

    let label: String
    let text: String
    let prominence: Prominence

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(text)
                .font(prominence == .primary ? .title3.weight(.semibold) : .body)
                .foregroundStyle(prominence == .primary ? .primary : .secondary)
                .lineLimit(prominence == .primary ? 2 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
