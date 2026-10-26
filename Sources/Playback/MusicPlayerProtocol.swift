import MediaPlayer

/// The parts of `MPMusicPlayerController` that MediaBridge's playback helpers and ``NowPlaying`` use.
///
/// `MPMusicPlayerController` conforms, so `applicationMusicPlayer` and `systemMusicPlayer` work
/// everywhere a player is expected. Conform your own type to drive previews and tests.
///
/// The members after `skipToBeginning()` came in 1.5 and have default implementations, so a
/// conforming type written before then keeps compiling.
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

    /// Seconds into the current song. Setting it seeks.
    var currentPlaybackTime: TimeInterval { get set }
    /// How fast the current song plays; `1` is normal speed.
    var currentPlaybackRate: Float { get set }
    var repeatMode: MPMusicRepeatMode { get set }
    var shuffleMode: MPMusicShuffleMode { get set }
    /// The current song's place in the queue, or `NSNotFound` when nothing is queued.
    var indexOfNowPlayingItem: Int { get }
    /// Loads the queue so ``play()`` starts without a delay.
    func prepareToPlay()

    /// The songs in the queue, in playing order, or `nil` when this player can't report its queue.
    ///
    /// MediaPlayer lets only `MPMusicPlayerController.applicationQueuePlayer` read its queue.
    @MainActor func queuedSongs() async throws(MusicLibraryError) -> [Song]?
}

extension MusicPlayerProtocol {
    public var currentPlaybackTime: TimeInterval {
        get { 0 }
        set {}
    }

    public var currentPlaybackRate: Float {
        get { 1 }
        set {}
    }

    public var repeatMode: MPMusicRepeatMode {
        get { .default }
        set {}
    }

    public var shuffleMode: MPMusicShuffleMode {
        get { .default }
        set {}
    }

    public var indexOfNowPlayingItem: Int { NSNotFound }

    public func prepareToPlay() {}

    @MainActor public func queuedSongs() async throws(MusicLibraryError) -> [Song]? { nil }
}

extension MPMusicPlayerController: MusicPlayerProtocol {}
