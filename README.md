<div align="center">
  <img src="Sources/Documentation.docc/Resources/media_bridge_logo.png" width="200" alt="MediaBridge Logo">
</div>

# MediaBridge

A Swift bridge for MPMediaLibrary integration.

[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkolomiiets-oleksii%2FMediaBridge%2Fbadge%3Ftype%3Dswift-versions)](https://github.com/kolomiiets-oleksii/MediaBridge)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-007AFF?logo=apple&logoColor=white)](https://www.apple.com/ios/)
[![visionOS 1.0+](https://img.shields.io/badge/🥽_visionOS-1.0+-7B68EE)](https://developer.apple.com/visionos/)
[![Latest Release](https://img.shields.io/github/v/release/kolomiiets-oleksii/MediaBridge?color=8B5CF6&logo=github&logoColor=white)](https://github.com/kolomiiets-oleksii/MediaBridge/releases)
[![Tests](https://github.com/kolomiiets-oleksii/MediaBridge/actions/workflows/test.yml/badge.svg)](https://github.com/kolomiiets-oleksii/MediaBridge/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-22C55E)](LICENSE)

## Requirements

- Swift 6.0 / Xcode 16 or later (CI builds against Swift 6.0 and runs the test suite on Swift 6.1, 6.2, 6.3 and 6.4)
- iOS 15.0+, visionOS 1.0+

## Retroactive conformances

MediaBridge declares `Optional: Comparable where Wrapped: Comparable` so optional key paths
(`\.releaseDate`, `\.name`) can be sorted. The conformance is public and reaches your module on
import; if another dependency declares the same one, you will need to disambiguate.

## Installation

Add MediaBridge to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/kolomiiets-oleksii/MediaBridge.git", from: "0.10.2")
]
```

## Quick Start

Add `NSAppleMusicUsageDescription` to your app's Info.plist first — iOS terminates the app on
the first library access without it.

```swift
let library = MusicLibrary()

// Optional: fetches request access on their own; call this only to choose when the prompt appears
if library.authorizationStatus == .notDetermined {
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

For more information visit [Documentation](https://swiftpackageindex.com/kolomiiets-oleksii/MediaBridge/documentation/mediabridge).

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to MediaBridge.

## License

MIT License - see the [LICENSE](LICENSE) file for details.
