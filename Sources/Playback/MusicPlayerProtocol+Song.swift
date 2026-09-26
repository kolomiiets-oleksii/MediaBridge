import MediaPlayer

extension MusicPlayerProtocol {
    /// The song playing now, or `nil` when nothing is.
    public var nowPlayingSong: Song? {
        nowPlayingItem.map(Song.init)
    }

    /// Replaces the player's queue with `songs`, in order.
    ///
    /// ```swift
    /// let player = MPMusicPlayerController.applicationMusicPlayer
    /// player.setQueue(with: try await library.fetch(.songs.filter(\.id == songID)))
    /// player.play()
    /// ```
    public func setQueue(with songs: [Song]) {
        setQueue(with: MPMusicPlayerMediaItemQueueDescriptor(songs: songs))
    }

    /// Replaces the player's queue with `songs`, in order, and starts playback at `start`, one of
    /// `songs`. Skipping back from `start` reaches the songs before it.
    ///
    /// ```swift
    /// List(songs) { song in
    ///     Button(song.title ?? "") {
    ///         player.setQueue(with: songs, startingAt: song)
    ///         player.play()
    ///     }
    /// }
    /// ```
    public func setQueue(with songs: [Song], startingAt start: Song) {
        setQueue(with: MPMusicPlayerMediaItemQueueDescriptor(songs: songs, startingAt: start))
    }

    /// Inserts `songs` after the current song, like Play Next in the Music app.
    ///
    /// `systemMusicPlayer` and `applicationQueuePlayer` support this; `applicationMusicPlayer`
    /// may ignore it.
    public func playNext(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        prepend(MPMusicPlayerMediaItemQueueDescriptor(songs: songs))
    }

    /// Adds `songs` to the end of the queue, like Play Last in the Music app.
    ///
    /// `systemMusicPlayer` and `applicationQueuePlayer` support this; `applicationMusicPlayer`
    /// may ignore it.
    public func playLater(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        append(MPMusicPlayerMediaItemQueueDescriptor(songs: songs))
    }
}

extension MPMusicPlayerMediaItemQueueDescriptor {
    convenience init(songs: [Song], startingAt start: Song? = nil) {
        self.init(itemCollection: MPMediaItemCollection(songs: songs))
        startItem = start?.mediaItem
    }
}

extension MPMediaItemCollection {
    convenience init(songs: [Song]) {
        self.init(items: songs.map(\.mediaItem))
    }
}
