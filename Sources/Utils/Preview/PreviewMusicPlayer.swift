import MediaPlayer

#if DEBUG
    /// A player for SwiftUI previews that keeps its queue in memory and plays nothing.
    ///
    /// It posts MediaPlayer's now-playing and playback-state notifications, so ``NowPlaying``
    /// follows it like a real player.
    ///
    /// ```swift
    /// #Preview {
    ///     MiniPlayer()
    ///         .musicPlayer(.preview(queue: previewSongs, state: .playing))
    /// }
    /// ```
    public final class PreviewMusicPlayer: MusicPlayerProtocol {
        private var items: [MPMediaItem]
        private var index: Int?
        public private(set) var playbackState: MPMusicPlaybackState {
            didSet { post(.MPMusicPlayerControllerPlaybackStateDidChange) }
        }

        init(queue: [MPMediaItem], state: MPMusicPlaybackState) {
            items = queue
            index = queue.isEmpty ? nil : 0
            playbackState = state
        }

        /// The songs in the queue, in playing order.
        public var queue: [Song] { items.map(Song.init) }

        public var nowPlayingItem: MPMediaItem? { index.map { items[$0] } }

        public func setQueue(with descriptor: MPMusicPlayerQueueDescriptor) {
            guard let descriptor = descriptor as? MPMusicPlayerMediaItemQueueDescriptor else { return }
            items = descriptor.itemCollection.items
            let start = descriptor.startItem.flatMap { start in items.firstIndex { $0 === start } }
            move(to: start ?? (items.isEmpty ? nil : 0))
        }

        public func prepend(_ descriptor: MPMusicPlayerQueueDescriptor) {
            let added = Self.items(in: descriptor)
            guard let index else { return append(descriptor) }
            items.insert(contentsOf: added, at: index + 1)
        }

        public func append(_ descriptor: MPMusicPlayerQueueDescriptor) {
            items.append(contentsOf: Self.items(in: descriptor))
            if index == nil, !items.isEmpty { move(to: 0) }
        }

        public func play() { playbackState = .playing }
        public func pause() { playbackState = .paused }
        public func stop() { playbackState = .stopped }

        public func skipToNextItem() {
            guard let index, index + 1 < items.count else { return }
            move(to: index + 1)
        }

        public func skipToPreviousItem() {
            guard let index, index > 0 else { return }
            move(to: index - 1)
        }

        public func skipToBeginning() {}

        public func beginGeneratingPlaybackNotifications() {}
        public func endGeneratingPlaybackNotifications() {}

        private func move(to newIndex: Int?) {
            index = newIndex
            post(.MPMusicPlayerControllerNowPlayingItemDidChange)
        }

        private func post(_ name: Notification.Name) {
            NotificationCenter.default.post(name: name, object: self)
        }

        private static func items(in descriptor: MPMusicPlayerQueueDescriptor) -> [MPMediaItem] {
            (descriptor as? MPMusicPlayerMediaItemQueueDescriptor)?.itemCollection.items ?? []
        }
    }

    extension MusicPlayerProtocol where Self == PreviewMusicPlayer {
        /// A preview player with `queue`, starting at its first song.
        public static func preview(queue: [MPMediaItem] = [], state: MPMusicPlaybackState = .stopped) -> PreviewMusicPlayer {
            PreviewMusicPlayer(queue: queue, state: state)
        }
    }
#endif
