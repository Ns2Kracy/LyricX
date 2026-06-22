import LyricXCore
import SwiftUI

struct FloatingLyricsView: View {
    let presentation: LyricOverlayPresentation
    let onClose: () -> Void

    var body: some View {
        lyricContent
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
            .frame(minWidth: 360, idealWidth: 640, minHeight: 112, idealHeight: 132)
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(presentation.backgroundOpacity * 0.55))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide Floating Lyrics")
                .help("Hide Floating Lyrics")
                .padding(10)
            }
    }

    private var lyricContent: some View {
        VStack(spacing: 6) {
            if presentation.usesKTV {
                ktvLine
            } else {
                Text(presentation.currentText)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            if let nextText = presentation.nextText {
                Text(nextText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.currentText)
    }

    private var ktvLine: some View {
        HStack(spacing: 0) {
            ForEach(Array(presentation.segments.enumerated()), id: \.offset) { _, segment in
                Text(segment.text)
                    .foregroundStyle(segment.isHighlighted ? Color.white : Color.white.opacity(0.35))
            }
        }
        .font(.system(size: 28, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}
