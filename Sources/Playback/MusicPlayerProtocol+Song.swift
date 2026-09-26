import MediaPlayer

extension MusicPlayerProtocol {
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
