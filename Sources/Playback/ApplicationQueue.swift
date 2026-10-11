import MediaPlayer

extension MPMusicPlayerController {
    /// The songs in the queue, in playing order. Only `applicationQueuePlayer` can report this;
    /// `nil` for the other players.
    ///
    /// ```swift
    /// let player = MPMusicPlayerController.applicationQueuePlayer
    /// let queue = try await player.queuedSongs() ?? []
    /// ```
    @MainActor
    public func queuedSongs() async throws(MusicLibraryError) -> [Song]? {
        guard let player = self as? MPMusicPlayerApplicationController else { return nil }
        return try await player.edit { _ in }
    }
}

extension MPMusicPlayerApplicationController {
    /// Removes `songs` from the queue. Songs that aren't queued are ignored.
    ///
    /// Together with `playNext(_:)` and `playLater(_:)`, this is what an Up Next screen needs.
    ///
    /// - Throws: ``MusicLibraryError/underlying(_:)`` with MediaPlayer's error
    @MainActor
    public func removeFromQueue(_ songs: [Song]) async throws(MusicLibraryError) {
        guard !songs.isEmpty else { return }
        let ids = Set(songs.map(\.id))
        _ = try await edit { queue in
            for item in queue.items where ids.contains(item.persistentID) {
                queue.remove(item)
            }
        }
    }

    // A queue transaction with no edits just reports the queue.
    @MainActor
    fileprivate func edit(
        _ transaction: @escaping @Sendable (MPMusicPlayerControllerMutableQueue) -> Void
    ) async throws(MusicLibraryError) -> [Song] {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                perform(queueTransaction: transaction) { queue, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: queue.items.map(Song.init))
                    }
                }
            }
        } catch {
            throw MusicLibraryError.wrapping(error)
        }
    }
}
