<div align="center">
  <img src="Sources/Documentation.docc/Resources/media_bridge_logo.png" width="200" alt="MediaBridge Logo">
</div>

# MediaBridge

A Swift bridge for MPMediaLibrary integration.

[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkolomiiets-oleksii%2FMediaBridge%2Fbadge%3Ftype%3Dswift-versions)](https://github.com/kolomiiets-oleksii/MediaBridge)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-007AFF?logo=apple&logoColor=white)](https://www.apple.com/ios/)
[![visionOS 1.0+](https://img.shields.io/badge/🥽_visionOS-1.0+-7B68EE)](https://developer.apple.com/visionos/)
[![Latest Release](https://img.shields.io/github/v/release/oleksiikolomiietssnapp/MediaBridge?color=8B5CF6&logo=github&logoColor=white)](https://github.com/oleksiikolomiietssnapp/MediaBridge/releases)
[![Tests](https://github.com/oleksiikolomiietssnapp/MediaBridge/actions/workflows/test.yml/badge.svg)](https://github.com/oleksiikolomiietssnapp/MediaBridge/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-22C55E)](LICENSE)

## Requirements

- Swift 6.0 / Xcode 16 or later (CI verifies Xcode 16.4; 16.0-16.3 are expected to work but are not built on every change)
- iOS 15.0+, visionOS 1.0+

## Retroactive conformances

MediaBridge declares `Optional: Comparable where Wrapped: Comparable` so optional key paths
(`\.releaseDate`, `\.name`) can be sorted. The conformance is public and reaches your module on
import; if another dependency declares the same one, you will need to disambiguate.

## Installation

Add MediaBridge to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/oleksiikolomiietssnapp/MediaBridge.git", from: "0.10.0")
]
```

## Quick Start

```swift
let library = MusicLibrary()

// Optional: Check or request authorization first
if library.authorizationStatus != .authorized {
    try await library.requestAuthorization()
}

// Fetch songs
let songs = try await library.songs()

// Fetch albums
let albums = try await library.albums()

// Fetch artists
let artists = try await library.artists()

// Fetch playlists
let playlists = try await library.playlists()
```

For SwiftUI, inject via environment:

```swift
extension EnvironmentValues {
    @Entry var library: MusicLibraryProtocol = MusicLibrary()
}

@Environment(\.library) var library

// Songs sorted by skip count
let songs = try await library.songs(sortedBy: \MPMediaItem.skipCount, order: .reverse)

// Albums sorted by track count
let albums = try await library.albums(sortedBy: \MPMediaItemCollection.count, order: .reverse)

// Filter by genre
let rockSongs = try await library.songs(matching: .genre("Rock"), comparisonType: .equalTo)
```

Both the service layer and authorization manager use production implementations by default (`.live`), but you can provide custom implementations for testing or specialized behavior.

## Migration

### 0.7.0

- `albumArtistID` predicate case now takes `UInt64` instead of `String`. Update any call sites using `.albumArtistID("...")` to pass a numeric ID instead.
- `fetchSongs`, `fetchSong`, and `fetch` are no longer protocol requirements. They remain available as deprecated extension methods but conformers no longer need to implement them.

## Documentation

For more information visit [Documentation](https://swiftpackageindex.com/kolomiiets-oleksii/MediaBridge/0.9.2/documentation/mediabridge).

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to MediaBridge.

## License

MIT License - see the [LICENSE](LICENSE) file for details.
