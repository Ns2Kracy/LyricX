import SwiftUI

@MainActor
struct FloatingLyricsView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: model.playback.isPlaying ? "music.note" : "pause.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(model.trackSummary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(primaryText)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.opacity)

            Text(secondaryText)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 28)
        .frame(width: 820, height: 116)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        }
        .colorScheme(.dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var primaryText: String {
        if let line = model.currentLine?.text.nilIfEmpty {
            return line
        }
        if model.playback.track != nil {
            return model.lyricsStatus
        }
        return model.playback.message ?? "Waiting for Spotify"
    }

    private var secondaryText: String {
        if let nextLine = model.nextLine?.text.nilIfEmpty {
            return nextLine
        }
        return model.playback.isPlaying ? "Listening for the next line" : "Playback paused"
    }

    private var accessibilitySummary: String {
        [model.trackSummary, primaryText, secondaryText].joined(separator: ", ")
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
