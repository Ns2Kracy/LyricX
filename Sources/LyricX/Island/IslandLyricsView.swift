import LyricXCore
import SwiftUI

struct IslandLyricsView: View {
    let presentation: LyricOverlayPresentation
    let isExpanded: Bool
    let onClose: () -> Void
    let onToggleClickThrough: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Group {
            if isExpanded {
                expandedBody
            } else {
                collapsedBody
            }
        }
        .padding(.horizontal, isExpanded ? 18 : 14)
        .padding(.vertical, isExpanded ? 12 : 7)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(presentation.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 24 : 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 24 : 19, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
        .animation(.snappy(duration: 0.22), value: isExpanded)
    }

    private var collapsedBody: some View {
        Text(presentation.currentText)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(0.78))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(presentation.currentText)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text("LyricX")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                Spacer(minLength: 12)

                islandButton(
                    "cursorarrow.rays",
                    action: onToggleClickThrough,
                    help: "Toggle Click Through"
                )
                islandButton(
                    "gearshape",
                    action: onOpenSettings,
                    help: "Open Settings"
                )
                islandButton(
                    "xmark",
                    action: onClose,
                    help: "Hide Island Lyrics"
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                if presentation.usesKTV {
                    ktvLine
                    nextLyricText
                } else {
                    expandedLyricText
                }
            }
        }
    }

    private var expandedLyricText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(presentation.currentText)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            if let nextText = presentation.nextText {
                Text(nextText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.currentText)
    }

    @ViewBuilder
    private var nextLyricText: some View {
        if let nextText = presentation.nextText {
            Text(nextText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var ktvLine: some View {
        HStack(spacing: 0) {
            ForEach(Array(presentation.segments.enumerated()), id: \.offset) { _, segment in
                Text(segment.text)
                    .foregroundStyle(segment.isHighlighted ? Color.white : Color.white.opacity(0.36))
            }
        }
        .font(.system(size: 20, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.62)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.currentText)
    }

    private func islandButton(_ systemName: String, action: @escaping () -> Void, help: String) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(help)
        .help(help)
    }
}
