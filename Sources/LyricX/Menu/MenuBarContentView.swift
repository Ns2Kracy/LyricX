import AppKit
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow

    let model: AppModel

    var body: some View {
        nowPlayingPanel
            .padding(10)
            .frame(width: 250, height: 125)
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
                size: 96
            )

            VStack(alignment: .leading, spacing: 7) {
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

                HStack(spacing: 14) {
                    Button {
                        model.previousTrack()
                    } label: {
                        Label("Previous Track", systemImage: "backward.fill")
                            .labelStyle(.iconOnly)
                            .font(.callout)
                    }
                    .disabled(!canControlPlayback)
                    .help("Previous Track")

                    Button {
                        model.playPause()
                    } label: {
                        Label(playPauseTitle, systemImage: playPauseIcon)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .disabled(!canControlPlayback)
                    .help(playPauseTitle)

                    Button {
                        model.nextTrack()
                    } label: {
                        Label("Next Track", systemImage: "forward.fill")
                            .labelStyle(.iconOnly)
                            .font(.callout)
                    }
                    .disabled(!canControlPlayback)
                    .help("Next Track")
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 3) {
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)

                    HStack {
                        Text(formatTime(model.playback.position))

                        Spacer()

                        Text(remainingTimeText)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var utilityMenu: some View {
        Menu {
            Button {
                openAppWindow(id: "main")
            } label: {
                Label("Open LyricX", systemImage: "rectangle.on.rectangle")
            }

            Button {
                openAppWindow(id: "settings")
            } label: {
                Label("Settings", systemImage: "gearshape")
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

    private func openAppWindow(id: String) {
        openWindow(id: id)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
