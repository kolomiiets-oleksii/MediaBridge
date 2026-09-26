import MediaPlayer

/// The parts of `MPMusicPlayerController` that MediaBridge's playback helpers and ``NowPlaying`` use.
///
/// `MPMusicPlayerController` conforms, so `applicationMusicPlayer` and `systemMusicPlayer` work
/// everywhere a player is expected. Conform your own type to drive previews and tests.
public protocol MusicPlayerProtocol: AnyObject {
    var nowPlayingItem: MPMediaItem? { get }
    var playbackState: MPMusicPlaybackState { get }

    func setQueue(with descriptor: MPMusicPlayerQueueDescriptor)
    func prepend(_ descriptor: MPMusicPlayerQueueDescriptor)
    func append(_ descriptor: MPMusicPlayerQueueDescriptor)

    func play()
    func pause()
    func stop()
    func skipToNextItem()
    func skipToPreviousItem()
    func skipToBeginning()

    func beginGeneratingPlaybackNotifications()
    func endGeneratingPlaybackNotifications()
}

extension MPMusicPlayerController: MusicPlayerProtocol {}
