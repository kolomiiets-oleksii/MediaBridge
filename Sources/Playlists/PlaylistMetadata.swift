import MediaPlayer

/// What a new playlist is called and how it's described, used when
/// ``MusicLibraryProtocol/playlist(id:orCreate:)`` has to create it.
public struct PlaylistMetadata: Sendable, Equatable {
    public var name: String
    public var descriptionText: String?
    /// The author shown under the playlist's name. When `nil`, the Music app shows your app's name.
    public var authorDisplayName: String?

    public init(name: String, descriptionText: String? = nil, authorDisplayName: String? = nil) {
        self.name = name
        self.descriptionText = descriptionText
        self.authorDisplayName = authorDisplayName
    }

    var creationMetadata: MPMediaPlaylistCreationMetadata {
        let metadata = MPMediaPlaylistCreationMetadata(name: name)
        if let descriptionText {
            metadata.descriptionText = descriptionText
        }
        if let authorDisplayName {
            metadata.authorDisplayName = authorDisplayName
        }
        return metadata
    }
}
