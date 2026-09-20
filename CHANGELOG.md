# Changelog

All notable changes to MediaBridge are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.3] - 2026-09-20

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

### Removed
- `Bool` and `MPMediaType` `Comparable` conformances; use the `FlagKey` overloads for booleans
- `MusicLibraryServiceError` and `MusicLibraryServiceProtocol.E` — the service no longer throws for empty results; queries that match nothing are logged instead

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

For detailed information about each release, see the [GitHub Releases](https://github.com/oleksiikolomiietssnapp/MediaBridge/releases) page.
