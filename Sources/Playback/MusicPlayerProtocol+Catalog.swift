import MediaPlayer

extension MusicPlayerProtocol {
    /// Replaces the queue with catalog items, by store ID. Songs, albums and playlists play;
    /// other kinds are skipped.
    ///
    /// The player needs Apple Music playback rights for the items.
    public func setQueue(with items: [CatalogItem]) {
        setQueue(withStoreIDs: items.filter(\.kind.isPlayableInStoreQueue).map(\.storeID))
    }

    /// Replaces the queue with the catalog items for these store IDs, such as ``CatalogItem/id``.
    public func setQueue(withStoreIDs storeIDs: [String]) {
        guard !storeIDs.isEmpty else { return }
        setQueue(with: MPMusicPlayerStoreQueueDescriptor(storeIDs: storeIDs))
    }

    /// Inserts catalog items after the current song. See ``playNext(_:)``.
    public func playNext(storeIDs: [String]) {
        guard !storeIDs.isEmpty else { return }
        prepend(MPMusicPlayerStoreQueueDescriptor(storeIDs: storeIDs))
    }

    /// Adds catalog items to the end of the queue. See ``playLater(_:)``.
    public func playLater(storeIDs: [String]) {
        guard !storeIDs.isEmpty else { return }
        append(MPMusicPlayerStoreQueueDescriptor(storeIDs: storeIDs))
    }
}
