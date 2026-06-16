import AppKit
import LyricXCore
import SwiftUI

struct ArtworkView: View {
    let artwork: TrackArtwork?
    let fallbackTitle: String
    var size: CGFloat = 156

    private let cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            if let image = artworkImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)

                VStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(fallbackTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.separator, lineWidth: 1)
        }
        .accessibilityLabel("Track artwork")
    }

    private var artworkImage: NSImage? {
        guard let artwork else {
            return nil
        }
        return NSImage(data: artwork.data)
    }
}
