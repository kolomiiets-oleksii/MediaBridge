# Changelog

All notable changes to MediaBridge are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.14.0] - 2026-09-25

### Added
- Playlist writes: `library.playlist(id:orCreate:)` gets or creates your app's playlist from a `PlaylistMetadata` (name, description, author), `library.playlist(id:)` looks one up, and `library.add(_:to:)` appends songs. Each checks authorization first.
- `MusicLibraryServiceProtocol.playlist(id:creating:)` and `add(_:to:)`, the service primitives behind the writes.
- `MusicLibraryError`: `playlistUnavailable(_:)` when MediaPlayer creates nothing, and `writesUnsupported` from the default implementations, so services and `MusicLibraryProtocol` conformers written before 0.14 keep compiling.
- `MediaPicker`, a SwiftUI wrapper for `MPMediaPickerController`, and the `.mediaPicker(isPresented:)` modifier that presents it in a sheet (iOS only; the picker isn't available on visionOS).
- `Playlist.authorDisplayName`.
- Preview libraries create playlists and add songs in memory.
- Example app: Save as Playlist, which adds the most skipped songs to a "Most Skipped" playlist without duplicates.

## [0.13.1] - 2026-09-25

### Changed
- `Album`, `Artist`, `Genre` and `Playlist` each live in their own source file. No API changes.
- The Example app uses the 0.13 API: `Song`, `LibraryQuery` sorting, the library's `ArtworkImage`, and `changes` to reload.

### Added
- Example app: a `-demoLibrary` launch argument (off by default in the shared scheme) that runs on sample songs with artwork, so the full UI works on a simulator.
- Example app: an Open Settings button when music library access is denied.

### Fixed
- Example app: the music library usage description now says why access is needed.

## [0.13.0] - 2026-09-25

### Added
- `Song`, `Album`, `Artist`, `Genre`, and `Playlist`: zero-copy wrappers over MediaPlayer objects whose properties are read only when accessed, each keeping its `mediaItem`, `mediaCollection`, or `mediaPlaylist`
- `LibraryQuery`, built from `Song.query` and the other models' `query`, with `filter(_:_:)`, `sorted(by:_:)`, `then(by:_:)`, and `limit(_:)`, run by `fetch(_:)` on any `MusicLibraryProtocol`
- `LibraryCondition`: `equals` and `contains` run inside MediaPlayer's query where the property supports it; `notEquals`, `greaterThan`, `lessThan`, `atLeast`, and `atMost` run in memory
- `Song.artwork(size:)`, `Album.artwork(size:)`, and the SwiftUI `ArtworkImage` view, rendering artwork on demand without storing it
- `MediaQueryRequest.filters` and `init(mediaType:filters:grouping:)` for requests with several predicates; `filter` and `init(mediaType:filter:grouping:)` still work

### Changed
- `MusicLibraryProtocol`'s default `items(_:)` and `collections(_:)` apply filters after the first in memory

## [0.12.0] - 2026-09-25

### Added
- `MusicLibraryProtocol.changes`, an `AsyncStream<Date>` that yields the library's modification date whenever it changes; `MusicLibrary(auth:service:changes:)` takes the source, `LiveLibraryChanges` by default
- `genres()`, `composers()`, `compilations()`, `podcasts()`, and `audiobooks()`, each with a `sortedBy:order:` variant
- `items(_:)` and `collections(_:)` on `MusicLibraryProtocol`, running any `MediaQueryRequest`
- A–Z index sections: `songSections()`, `albumSections()`, `artistSections()`, and the general `itemSections(_:)` and `collectionSections(_:)`, returning `MediaSection` values; the live service uses MediaPlayer's own section index
- Filters: `isCloudItem`, `hasProtectedAsset`, `isCompilation`, `playCount`, `podcastTitle`, `podcastID`, `playlistAttributes`, and `playlistCloudID`

### Changed
- `MusicLibraryProtocol`, `MusicLibraryServiceProtocol`, and `MediaQueryProtocol` gain requirements for the above, each with a default implementation, so existing conformers keep compiling
- `MediaItemPredicateInfo` has new cases; an exhaustive `switch` over it needs them or a `default`

### Deprecated
- Every deprecated API now says it will be removed in 1.0.0: the `fetch…` methods, `PreviewMusicLibrary` and its initializer, and the old `.preview(...)` parameters

## [0.11.0] - 2026-09-25

### Changed
- **Breaking for custom services:** `MusicLibraryServiceProtocol` requires `items(_:)` and `collections(_:)`, which take a `MediaQueryRequest`, instead of `fetchAll`, `fetch`, `fetchAllCollections`, `fetchCollections`, `fetchAllPlaylists`, and `fetchPlaylists`. `MusicLibrary` builds songs, albums, artists, and playlists from these, and filters playlists itself
- Previews run through the real `MusicLibrary`, so sorting, filtering, and the authorization flow behave as they do on device; `.accessDenied` and the other presets return `MusicLibrary`
- A preview whose access ends up denied or restricted throws `AuthorizationManagerError` from fetches and `requestAuthorization()`, matching the live library
- `AuthorizationManagerProtocol` and `MusicLibraryServiceProtocol` no longer declare the unused associated types `T` and `Q`; the public `AuthorizationManagerProtocol.T` typealias is removed

### Added
- `MediaQueryRequest`, describing a query by media type, optional filter, and grouping
- `.preview(authStatus:authStatusAfterRequest:songs:albums:artists:playlists:)`, whose predicates are evaluated in memory
- `MediaItemPredicateInfo` conforms to `Equatable`

### Deprecated
- `PreviewMusicLibrary`, now a typealias for `MusicLibrary`, and its initializer
- `.preview(...)` with the `fetchedAllMedia`, `fetchedMedia`, `fetchedSongs`, `filteredSongs`, `filteredAlbums`, `filteredArtists`, and `filteredPlaylists` parameters

## [0.10.3] - 2026-09-25

### Fixed
- `MusicLibrary` methods inherit their documentation from `MusicLibraryProtocol` instead of carrying stale copies; `requestAuthorization()` no longer claims to return a non-authorized status

## [0.10.2] - 2026-09-22

### Added
- `AuthorizationManager.init()` and `MusicLibraryService.init()` are public, so the generic types can be built with a custom `MediaLibraryProtocol` or `MediaQueryProtocol`
- Documentation: `NSAppleMusicUsageDescription` setup, SwiftUI previews, and Topics for `SortKey`, `FlagKey`, and `PreviewMusicLibrary`

### Fixed
- Documentation for `albums()` and `artists()` claimed reverse order; results keep library order, as for every call with a `nil` sort key
- Documentation for `requestAuthorization()` and `authorize()` said they return the current status; they return `.authorized` or throw
- Documentation no longer says fetches require authorization first; they request it automatically
- `MusicLibraryServiceProtocol` documentation no longer describes the error type removed in 0.10.0
- SwiftUI examples use `try?` inside `.task`, which doesn't accept throwing code

## [0.10.1] - 2026-09-22

### Changed
- CI runs the test suite on Swift 6.1, 6.2, 6.3 and 6.4, and builds the Swift 6.0 floor

## [0.10.0] - 2026-09-20

### Changed
- Requires Swift 6.0 / Xcode 16; reverses the `5.9` manifest from 0.9.1, which the sources never compiled under
- `songs()`, `albums()`, `artists()`, `playlists()` are available to every `MusicLibraryProtocol` conformer, not just `MusicLibrary`
- Queries with no results return an empty array instead of throwing, and log at `info`
- `MusicLibraryProtocol`, `AuthorizationManagerProtocol`, and `MusicLibraryServiceProtocol` require `Sendable`
- Compiles in the Swift 6 language mode (`swiftLanguageModes: [.v6]`), so data-race safety is enforced at compile time
- Log subsystem uses the host app's bundle identifier

### Added
- `FlagKey` sorting overloads for `Bool` key paths, e.g. `songs(sortedBy: \.isExplicitItem, order:)`
- `PreviewMusicLibrary.init` is public; `.preview()` accepts `filteredArtists` and `filteredPlaylists`

### Fixed
- `.contains` is no longer applied to the media-type predicate, which accepts only `.equalTo`
- `Optional` comparison is a total order; `nil` sorts first, and any `Comparable` wrapped type is supported
- Authorization result is checked after a request instead of relying on the manager throwing
- `MusicLibrary.fetchSong(with:)` defaults `comparisonType` to `.equalTo`, matching the protocol extension it was shadowing
- Deprecation attributes no longer sit above doc comments, so DocC keeps the documentation for `fetchSongs()` and `fetchSong(with:)`

### Removed
- `Bool` and `MPMediaType` `Comparable` conformances; use the `FlagKey` overloads for booleans
- `MusicLibraryServiceError` and `MusicLibraryServiceProtocol.E` — the service no longer throws for empty results, so `catch` clauses for these cases can be deleted

## [0.9.2] - 2026-03-08

### Fixed
- Removed a trailing comma in `Package.swift` that Swift 5.9 toolchains could not parse

## [0.9.1] - 2026-03-08

### Fixed
- Lowered `swift-tools-version` from `6.0` to `5.9` so the package manifest is readable by Swift 5.9+ toolchains

## [0.9.0] - 2026-03-08

### Added
- `playlists()` - fetch all playlists without sorting
- `playlists(sortedBy:order:)` - fetch playlists with optional sorting; returns `[MPMediaPlaylist]` for full access to `name`, `playlistAttributes`, `descriptionText`, `seedItems`, and `cloudGlobalID`
- `playlists(matching:_:)` - fetch playlists matching a predicate (no `groupingType` parameter — playlists are always `.playlist` grouped)
- `.playlistName(String)` and `.playlistID(UInt64)` predicate cases added to `MediaItemPredicateInfo`
- `fetchAllPlaylists()` and `fetchPlaylists(with:comparisonType:)` added to `MusicLibraryServiceProtocol`

## [0.8.0] - 2026-03-08

### Added
- `artists()` - fetch all artists without sorting
- `artists(sortedBy:order:)` - fetch artists with optional sorting
- `artists(matching:_:groupingType:)` - fetch artists matching a predicate

## [0.7.0] - 2026-03-08

### Breaking Changes
- `albumArtistID` predicate case now takes `UInt64` instead of `String`, consistent with all other ID-based cases and with the underlying `MPMediaItemPropertyAlbumArtistPersistentID` type

### Removed
- Deprecated methods `fetchSongs(sortedBy:order:)`, `fetchSong(with:comparisonType:)`, and `fetch(_:with:_:groupingType:)` are no longer protocol requirements — conformers no longer need to implement them. Default implementations forwarding to the current API are provided via a protocol extension.
- Removed unused empty `MediaItem` internal protocol

### Fixed
- `MediaItemPredicateInfo.description` had a stray `)` producing malformed error messages and log entries
- `MusicLibraryServiceError.==` and `AuthorizationManagerError.==` now compare structurally instead of via `errorDescription` strings
- Removed infinite recursion in `songs(matching:comparisonType:)` protocol extension
- `AuthorizationManager` is now `final`
- `log` global in `Logger.swift` is now explicitly `internal`

## [0.6.3] - 2026-02-08

### Changed
- Improved `SortKey` type definition
- Ensured `albums` methods are consistently defined on `MusicLibraryProtocol`

## [0.6.2] - 2026-02-08

### Added
- `albums` methods added to `MusicLibraryProtocol`

## [0.6.1] - 2026-02-08

### Added
- `albums(sortedBy:order:)` added to `MusicLibraryProtocol`

## [0.6.0] - 2026-02-07

### Added
- `albums()` - fetch all albums without sorting
- `albums(sortedBy:order:)` - fetch albums with optional sorting
- `albums(matching:_:groupingType:)` - fetch albums matching a predicate
- `mediaItemCollections(ofType:matching:_:groupingType:)` to `MusicLibraryProtocol`

### Changed
- Separated authorization types into individual files
- Improved error type naming
- Improved DocC documentation comments

## [0.5.1] - 2026-01-14

### Fixed
- Fixed typo in `Package.swift` to allow Swift Package Index to build against Swift 6 and lower versions

## [0.5.0] - 2025-12-06

### Added
- New Swift-like method names for cleaner, more idiomatic API:
  - `songs()` - fetch all songs without sorting
  - `songs(sortedBy:order:)` - fetch songs with optional sorting
  - `songs(matching:comparisonType:)` - fetch songs matching a predicate
  - `mediaItems(ofType:matching:comparisonType:groupingType:)` - fetch generic media items

### Deprecated
- `fetchSongs()` - use `songs()` instead
- `fetchSongs(sortedBy:order:)` - use `songs(sortedBy:order:)` instead
- `fetchSong(with:comparisonType:)` - use `songs(matching:comparisonType:)` instead
- `fetch(_:with:comparisonType:groupingType:)` - use `mediaItems(ofType:matching:comparisonType:groupingType:)` instead

### Changed
- All documentation and examples now use new method names
- Example app updated to demonstrate new API
- Old methods remain functional but show deprecation warnings

## [0.4.1] - 2025-12-06

### Added
- Debug preview mocks for `MusicLibraryProtocol` to support SwiftUI previews during development

## [0.4.0] - 2025-12-05

### Added
- `authorizationStatus` property to `MusicLibraryProtocol` for checking music library access permissions
- `requestAuthorization()` method to explicitly request music library access from the user

## [0.3.1] - 2025-12-03

### Added
- Vision OS platform information in documentation

### Changed
- Updated badge links in README

### Fixed
- Removed duplicate Swift version badge

## [0.3.0] - 2025-12-03

### Changed
- Updated badges formatting in README for Swift and iOS versions

## [0.2.8] - 2025-12-03

### Added
- GitHub Actions workflow for automated testing on iOS simulator

## [0.2.7] - 2025-12-03

### Added
- Badges to README (Swift version, iOS version, License, Latest Release, SPI badges)

## [0.2.6] - 2025-12-03

### Added
- CHANGELOG.md file for version documentation

## [0.2.5] - 2025-12-03

### Added
- .spi.yml configuration for Swift Package Index optimization

## [0.2.4] - 2025-12-03

### Added
- Pull request template for standardized PR descriptions

## [0.2.3] - 2025-12-03

### Added
- MIT License file
- License information in README

## [0.2.2] - 2025-12-03

### Added
- Comprehensive DocC documentation for service layer
- Documentation page polishing
- README improvements

## [0.2.1] - 2025-11-15

### Added
- Unit tests for service layer
- Mock implementations for testing

## [0.2.0] - 2025-11-15

### Added
- Authorization manager with media library access control
- Service layer for media queries
- Protocol-based architecture for dependency injection
- Mock implementations for testing
- Comprehensive DocC documentation

## [0.1.0] - 2025-11-15

### Added
- Initial project setup
- Basic MusicLibrary implementation
- MPMediaLibrary integration
- Swift Testing framework integration
- Package.swift configuration

---

For detailed information about each release, see the [GitHub Releases](https://github.com/kolomiiets-oleksii/MediaBridge/releases) page.
