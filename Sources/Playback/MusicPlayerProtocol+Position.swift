import MediaPlayer

extension MusicPlayerProtocol {
    /// Where playback is now, to compute progress from instead of polling.
    ///
    /// See ``PlaybackPosition``. ``NowPlaying`` exposes it as `$song.position`.
    public var playbackPosition: PlaybackPosition {
        let time = currentPlaybackTime
        let speed = Double(currentPlaybackRate)
        return PlaybackPosition(
            time: time.isFinite ? time : 0,
            rate: playbackState == .playing ? (speed > 0 ? speed : 1) : 0
        )
    }

    /// The current song's place in the queue, or `nil` when nothing is queued.
    public var nowPlayingIndex: Int? {
        let index = indexOfNowPlayingItem
        return index == NSNotFound ? nil : index
    }
}
