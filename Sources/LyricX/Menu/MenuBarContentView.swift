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
            .padding(12)
            .frame(width: 300, height: 150)
    }

    private func boolBinding(_ keyPath: ReferenceWritableKeyPath<AppModel, Bool>) -> Binding<Bool> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { model[keyPath: keyPath] = $0 }
        )
    }

    private var nowPlayingPanel: some View {
        HStack(alignment: .top, spacing: 10) {
            ArtworkView(
                artwork: model.artwork,
                fallbackTitle: model.playback.track?.album ?? "LyricX",
                size: 120
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 4) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.playback.track?.title ?? "No Spotify Track")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        Text(model.playback.track?.artist ?? model.playback.message ?? "Waiting for Spotify")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 2)

                    utilityMenu
                }

                Spacer(minLength: 0)
                playbackToolbar
                Spacer(minLength: 0)
                progressBlock
            }
            .frame(height: 120)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var playbackToolbar: some View {
        ZStack {
            HStack(spacing: 0) {
                Button {
                    model.previousTrack()
                } label: {
                    Label("Previous Track", systemImage: "backward.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16, weight: .medium))
                }
                .disabled(!canControlPlayback)
                .help("Previous Track")
                .frame(width: elapsedTimeColumnWidth, alignment: .trailing)

                Spacer(minLength: 0)

                Button {
                    model.nextTrack()
                } label: {
                    Label("Next Track", systemImage: "forward.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16, weight: .medium))
                }
                .disabled(!canControlPlayback)
                .help("Next Track")
                .frame(width: remainingTimeColumnWidth, alignment: .leading)
            }

            Button {
                model.playPause()
            } label: {
                Label(playPauseTitle, systemImage: playPauseIcon)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 23, weight: .semibold))
            }
            .disabled(!canControlPlayback)
            .help(playPauseTitle)
            .frame(width: 32, alignment: .center)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var progressBlock: some View {
        VStack(spacing: 4) {
            ProgressView(value: progressValue)
                .progressViewStyle(.linear)
                .controlSize(.mini)

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

            Toggle(isOn: boolBinding(\.showsFloatingLyrics)) {
                Label("Floating Lyrics", systemImage: "macwindow")
            }

            Toggle(isOn: boolBinding(\.showsIslandLyrics)) {
                Label("Island Lyrics", systemImage: "capsule")
            }

            Toggle(isOn: boolBinding(\.floatingLyricsLocked)) {
                Label("Lock Floating Lyrics", systemImage: "lock")
            }

            Toggle(isOn: boolBinding(\.floatingLyricsClickThrough)) {
                Label("Floating Click Through", systemImage: "cursorarrow.rays")
            }

            Toggle(isOn: boolBinding(\.islandLyricsClickThrough)) {
                Label("Island Click Through", systemImage: "cursorarrow.rays")
            }

            Toggle(isOn: boolBinding(\.floatingLyricsKTVEnabled)) {
                Label("Floating KTV Mode", systemImage: "textformat")
            }

            Toggle(isOn: boolBinding(\.islandLyricsKTVEnabled)) {
                Label("Island KTV Mode", systemImage: "textformat.alt")
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
