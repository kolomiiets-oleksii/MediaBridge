import Foundation
import MediaPlayer

/// A playlist in the user's music library.
public struct Playlist: Identifiable, Hashable, @unchecked Sendable {
    /// The underlying playlist, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaPlaylist: MPMediaPlaylist

    public init(_ mediaPlaylist: MPMediaPlaylist) {
        self.mediaPlaylist = mediaPlaylist
    }

    public var id: MPMediaEntityPersistentID { reader.number(MPMediaPlaylistPropertyPersistentID)?.uint64Value ?? 0 }
    public var name: String? { reader.value(MPMediaPlaylistPropertyName) }
    public var descriptionText: String? { reader.value(MPMediaPlaylistPropertyDescriptionText) }
    /// The playlist's iCloud Music Library identifier, when it has one.
    public var cloudID: String? { reader.value(MPMediaPlaylistPropertyCloudGlobalID) }
    public var isSmart: Bool { attributes.contains(.smart) }
    public var isGenius: Bool { attributes.contains(.genius) }
    /// Whether the playlist was created on the device rather than synced.
    public var isOnTheGo: Bool { attributes.contains(.onTheGo) }
    public var songCount: Int { mediaPlaylist.count }
    public var songs: [Song] { mediaPlaylist.items.map(Song.init) }

    public static func == (lhs: Playlist, rhs: Playlist) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var attributes: MPMediaPlaylistAttribute {
        MPMediaPlaylistAttribute(rawValue: reader.number(MPMediaPlaylistPropertyPlaylistAttributes)?.uintValue ?? 0)
    }

    private var reader: EntityReader { EntityReader(mediaPlaylist) }
}

extension Playlist: LibraryElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(grouping: .playlist) }

    public static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws -> [Playlist] {
        try await library.collections(request).compactMap { ($0 as? MPMediaPlaylist).map(Playlist.init) }
    }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Playlist.name, let value as String): .playlistName(value)
        case (\Playlist.cloudID, let value as String): .playlistCloudID(value)
        case (\Playlist.id, let value as UInt64): .playlistID(value)
        default: nil
        }
    }
}
