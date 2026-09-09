import LyricXMac
import SwiftUI
import WebKit

struct SpotifyWebPlaybackHostView: NSViewRepresentable {
    let service: SpotifyWebPlaybackService

    func makeNSView(context: Context) -> WKWebView {
        service.playerView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
