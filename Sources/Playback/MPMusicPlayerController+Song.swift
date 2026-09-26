import MediaPlayer

extension MPMusicPlayerController {
    /// Replaces the player's queue with `songs`, in order.
    ///
    /// ```swift
    /// let player = MPMusicPlayerController.applicationMusicPlayer
    /// player.setQueue(with: try await library.fetch(.songs.filter(\.id == songID)))
    /// player.play()
    /// ```
    public func setQueue(with songs: [Song]) {
        setQueue(with: MPMediaItemCollection(songs: songs))
    }
}

extension MPMediaItemCollection {
    convenience init(songs: [Song]) {
        self.init(items: songs.map(\.mediaItem))
    }
}
