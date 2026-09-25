import Foundation
import MediaPlayer

/// An album in the user's music library.
///
/// Like ``Song``, an `Album` wraps its `MPMediaItemCollection` without copying: properties are
/// read from the collection's representative song when you access them.
public struct Album: Identifiable, Hashable, @unchecked Sendable {
    /// The underlying collection, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaCollection: MPMediaItemCollection

    public init(_ mediaCollection: MPMediaItemCollection) {
        self.mediaCollection = mediaCollection
    }

    public var id: MPMediaEntityPersistentID { representative.number(MPMediaItemPropertyAlbumPersistentID)?.uint64Value ?? 0 }
    public var title: String? { representative.value(MPMediaItemPropertyAlbumTitle) }
    public var artist: String? { representative.value(MPMediaItemPropertyAlbumArtist) }
    public var genre: String? { representative.value(MPMediaItemPropertyGenre) }
    public var releaseDate: Date? { representative.value(MPMediaItemPropertyReleaseDate) }
    public var isCompilation: Bool { representative.number(MPMediaItemPropertyIsCompilation)?.boolValue ?? false }
    public var songCount: Int { mediaCollection.count }
    public var songs: [Song] { mediaCollection.items.map(Song.init) }

    public static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var representative: EntityReader { EntityReader(mediaCollection.representativeItem) }
}

/// An artist in the user's music library, with the songs credited to them.
public struct Artist: Identifiable, Hashable, @unchecked Sendable {
    /// The underlying collection, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaCollection: MPMediaItemCollection

    public init(_ mediaCollection: MPMediaItemCollection) {
        self.mediaCollection = mediaCollection
    }

    public var id: MPMediaEntityPersistentID { representative.number(MPMediaItemPropertyArtistPersistentID)?.uint64Value ?? 0 }
    public var name: String? { representative.value(MPMediaItemPropertyArtist) }
    public var songCount: Int { mediaCollection.count }
    public var songs: [Song] { mediaCollection.items.map(Song.init) }

    public static func == (lhs: Artist, rhs: Artist) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var representative: EntityReader { EntityReader(mediaCollection.representativeItem) }
}

/// A genre in the user's music library, with its songs.
public struct Genre: Identifiable, Hashable, @unchecked Sendable {
    /// The underlying collection, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaCollection: MPMediaItemCollection

    public init(_ mediaCollection: MPMediaItemCollection) {
        self.mediaCollection = mediaCollection
    }

    public var id: MPMediaEntityPersistentID { representative.number(MPMediaItemPropertyGenrePersistentID)?.uint64Value ?? 0 }
    public var name: String? { representative.value(MPMediaItemPropertyGenre) }
    public var songCount: Int { mediaCollection.count }
    public var songs: [Song] { mediaCollection.items.map(Song.init) }

    public static func == (lhs: Genre, rhs: Genre) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var representative: EntityReader { EntityReader(mediaCollection.representativeItem) }
}

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

struct EntityReader {
    let entity: MPMediaEntity?

    init(_ entity: MPMediaEntity?) {
        self.entity = entity
    }

    func value<T>(_ property: String) -> T? {
        entity?.value(forProperty: property) as? T
    }

    func number(_ property: String) -> NSNumber? {
        entity?.value(forProperty: property) as? NSNumber
    }
}

// MARK: - Queries

extension Album: LibraryElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(mediaType: .music, grouping: .album) }

    public static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws -> [Album] {
        try await library.collections(request).map(Album.init)
    }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Album.title, let value as String): .albumTitle(value)
        case (\Album.artist, let value as String): .albumArtist(value)
        case (\Album.genre, let value as String): .genre(value)
        case (\Album.isCompilation, let value as Bool): .isCompilation(value)
        case (\Album.id, let value as UInt64): .albumID(value)
        default: nil
        }
    }
}

extension Artist: LibraryElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(mediaType: .music, grouping: .artist) }

    public static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws -> [Artist] {
        try await library.collections(request).map(Artist.init)
    }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Artist.name, let value as String): .artist(value)
        case (\Artist.id, let value as UInt64): .artistID(value)
        default: nil
        }
    }
}

extension Genre: LibraryElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(mediaType: .music, grouping: .genre) }

    public static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws -> [Genre] {
        try await library.collections(request).map(Genre.init)
    }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Genre.name, let value as String): .genre(value)
        case (\Genre.id, let value as UInt64): .genreID(value)
        default: nil
        }
    }
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
