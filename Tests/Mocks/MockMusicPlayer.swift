import MediaPlayer

@testable import MediaBridge

final class MockMusicPlayer: MusicPlayerProtocol {
    var nowPlayingItem: MPMediaItem?
    var playbackState: MPMusicPlaybackState = .stopped
    private(set) var queued: [MPMusicPlayerQueueDescriptor] = []
    private(set) var prepended: [MPMusicPlayerQueueDescriptor] = []
    private(set) var appended: [MPMusicPlayerQueueDescriptor] = []
    private(set) var notificationRequests = 0

    func setQueue(with descriptor: MPMusicPlayerQueueDescriptor) { queued.append(descriptor) }
    func prepend(_ descriptor: MPMusicPlayerQueueDescriptor) { prepended.append(descriptor) }
    func append(_ descriptor: MPMusicPlayerQueueDescriptor) { appended.append(descriptor) }
    func play() { playbackState = .playing }
    func pause() { playbackState = .paused }
    func stop() { playbackState = .stopped }
    func skipToNextItem() {}
    func skipToPreviousItem() {}
    func skipToBeginning() {}
    func beginGeneratingPlaybackNotifications() { notificationRequests += 1 }
    func endGeneratingPlaybackNotifications() { notificationRequests -= 1 }
}

extension MPMusicPlayerQueueDescriptor {
    var songIdentities: [ObjectIdentifier] {
        (self as? MPMusicPlayerMediaItemQueueDescriptor)?.itemCollection.items.map(ObjectIdentifier.init) ?? []
    }

    var startIdentity: ObjectIdentifier? {
        (self as? MPMusicPlayerMediaItemQueueDescriptor)?.startItem.map(ObjectIdentifier.init)
    }
}
