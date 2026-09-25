import Foundation
import MediaPlayer

/// A type-safe predicate for filtering media items in the music library.
///
/// Use `MediaItemPredicateInfo` to specify filtering criteria when fetching songs or other media items.
/// Each case represents a different property you can filter by (artist, title, genre, etc.).
///
/// ## Example
/// ```swift
/// let library = MusicLibrary()
/// let taylorSwiftSongs = try await library.mediaItems(
///     ofType: .music,
///     matching: .artist("Taylor Swift"),
///     .contains,
///     groupingType: .album
/// )
/// ```
public enum MediaItemPredicateInfo: Sendable, Equatable {
    /// Filter by a media item's persistent ID (unique identifier).
    case persistentID(UInt64)

    /// Filter by media type (music, podcast, audiobook, etc.).
    case mediaType(MPMediaType)

    /// Filter by the title of the media item.
    case title(String)

    /// Filter by album title.
    case albumTitle(String)

    /// Filter by album's persistent ID.
    case albumID(UInt64)

    /// Filter by artist name.
    case artist(String)

    /// Filter by artist's persistent ID.
    case artistID(UInt64)

    /// Filter by album artist name.
    case albumArtist(String)

    /// Filter by album artist's persistent ID.
    case albumArtistID(UInt64)

    /// Filter by genre name.
    case genre(String)

    /// Filter by genre's persistent ID.
    case genreID(UInt64)

    /// Filter by composer name.
    case composer(String)

    /// Filter by composer's persistent ID.
    case composerID(UInt64)

    /// Filter by playlist name.
    case playlistName(String)

    /// Filter by playlist's persistent ID.
    case playlistID(UInt64)

    /// Converts this predicate info to an `MPMediaPropertyPredicate`.
    ///
    /// This method is typically called internally by library methods, but can be used
    /// if you need to create a predicate directly for advanced queries.
    ///
    /// - Parameter comparisonType: How to compare the predicate value (defaults to `.equalTo`).
    ///   Use `.contains` for string-based predicates to perform substring matching.
    /// - Returns: An `MPMediaPropertyPredicate` configured with this predicate's property and value
    ///
    /// ## Example
    /// ```swift
    /// let predicate = MediaItemPredicateInfo.artist("Taylor Swift")
    ///     .predicate(using: .contains)
    /// ```
    public func predicate(
        using comparisonType: MPMediaPredicateComparison = .equalTo
    ) -> MPMediaPropertyPredicate {
        MPMediaPropertyPredicate(
            value: value,
            forProperty: property,
            comparisonType: comparisonType
        )
    }

    public var description: String {
        "\(property) with value `\(String(describing: value))`"
    }

    private var property: String {
        switch self {
        case .persistentID: MPMediaItemPropertyPersistentID
        case .mediaType: MPMediaItemPropertyMediaType
        case .title: MPMediaItemPropertyTitle

        case .albumTitle: MPMediaItemPropertyAlbumTitle
        case .albumID: MPMediaItemPropertyAlbumPersistentID

        case .artist: MPMediaItemPropertyArtist
        case .artistID: MPMediaItemPropertyArtistPersistentID

        case .albumArtist: MPMediaItemPropertyAlbumArtist
        case .albumArtistID: MPMediaItemPropertyAlbumArtistPersistentID

        case .genre: MPMediaItemPropertyGenre
        case .genreID: MPMediaItemPropertyGenrePersistentID

        case .composer: MPMediaItemPropertyComposer
        case .composerID: MPMediaItemPropertyComposerPersistentID

        case .playlistName: MPMediaPlaylistPropertyName
        case .playlistID: MPMediaPlaylistPropertyPersistentID
        }
    }

    private var value: Any? {
        switch self {
        case .persistentID(let id): id
        case .mediaType(let type): type.rawValue
        case .title(let title): title

        case .albumTitle(let albumTitle): albumTitle
        case .albumID(let albumId): albumId

        case .artist(let artist): artist
        case .artistID(let artistId): artistId

        case .albumArtist(let albumArtist): albumArtist
        case .albumArtistID(let albumArtistId): albumArtistId

        case .genre(let genre): genre
        case .genreID(let genreId): genreId

        case .composer(let composer): composer
        case .composerID(let composerId): composerId

        case .playlistName(let name): name
        case .playlistID(let id): id
        }
    }
}
