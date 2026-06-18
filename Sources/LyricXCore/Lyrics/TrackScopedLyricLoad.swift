public enum TrackScopedLyricLoad {
    public static func canApply(
        loadedFor loadedTrack: PlaybackTrack,
        currentTrack: PlaybackTrack?,
        requestedTrack: PlaybackTrack?
    ) -> Bool {
        currentTrack == loadedTrack && requestedTrack == loadedTrack
    }
}
