<div align="center">
  <img src="Sources/Documentation.docc/Resources/media_bridge_logo.png" width="200" alt="MediaBridge Logo">
</div>

# MediaBridge

The user's music library in modern Swift: typed models, key-path queries, typed errors, and `@MediaQuery` for SwiftUI. Built on MediaPlayer, iOS 15 and later.

[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkolomiiets-oleksii%2FMediaBridge%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/kolomiiets-oleksii/MediaBridge)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkolomiiets-oleksii%2FMediaBridge%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/kolomiiets-oleksii/MediaBridge)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-007AFF?logo=apple&logoColor=white)](https://www.apple.com/ios/)
[![visionOS 1.0+](https://img.shields.io/badge/🥽_visionOS-1.0+-7B68EE)](https://developer.apple.com/visionos/)
[![Latest Release](https://img.shields.io/github/v/release/kolomiiets-oleksii/MediaBridge?color=8B5CF6&logo=github&logoColor=white)](https://github.com/kolomiiets-oleksii/MediaBridge/releases)
[![Tests](https://github.com/kolomiiets-oleksii/MediaBridge/actions/workflows/test.yml/badge.svg)](https://github.com/kolomiiets-oleksii/MediaBridge/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-22C55E)](LICENSE)

## Requirements

- Swift 6.0 / Xcode 16 or later (CI builds against Swift 6.0 and runs the test suite on Swift 6.1, 6.2, 6.3 and 6.4)
- iOS 15.0+, visionOS 1.0+

## Installation

Add MediaBridge to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/kolomiiets-oleksii/MediaBridge.git", from: "1.0.0")
]
```

Add `NSAppleMusicUsageDescription` to your app's Info.plist, saying why you need the library.
iOS terminates the app on the first library access without it.

## SwiftUI

```swift
struct SongList: View {
    @MediaQuery(.songs.sorted(by: \.playCount, .reverse)) var songs

    var body: some View {
        List(songs) { song in
            HStack {
                ArtworkImage(song, size: 44)
                Text(song.title ?? "Unknown")
            }
        }
        .refreshable { await $songs.reload() }
    }
}
```

`@MediaQuery` asks for access on its first fetch, and refetches when the query or the library
changes. `$songs.isLoading` and `$songs.error` report its state.

Name the queries your app repeats:

```swift
extension LibraryQuery where Element == Song {
    static var mostSkipped: Self { .songs.filter(\.skipCount > 0).sorted(by: \.skipCount, .reverse) }
}

@MediaQuery(.mostSkipped) var songs
```

`ArtworkImage` decodes artwork off the main thread. Give it your own placeholder and corner radius:

```swift
ArtworkImage(song, size: 48, cornerRadius: 4)
    .placeholder { Image("logo").resizable().padding(8) }
```

## Queries

Start from `.songs`, `.albums`, `.artists`, `.genres`, `.composers`, `.playlists`, `.podcasts`,
`.podcastEpisodes`, `.audiobooks`, or `.compilations`, then filter, sort, and limit:

```swift
let library = MusicLibrary()

let topLocal = try await library.fetch(
    .songs
        .filter(\.isCloudItem == false)      // runs inside MediaPlayer's query
        .filter(\.playCount >= 10)           // runs in memory
        .sorted(by: \.playCount, .reverse)
        .then(by: \.title)
        .limit(25)
)

let sections = try await library.sections(.albums)   // A–Z, like the Music app
```

Every call throws one typed error:

```swift
do {
    songs = try await library.fetch(.songs)
} catch .unauthorized(.denied) {
    showSettingsButton = true
} catch {
    message = error.localizedDescription
}
```

## Playlists and Apple Music

```swift
let playlist = try await library.playlist(id: mostSkippedID, orCreate: PlaylistMetadata(name: "Most Skipped"))
try await library.add(songs, to: playlist)
try await library.add(productID: "1440839718", to: playlist)   // Apple Music subscribers
```

Let people pick songs with the system picker (iOS):

```swift
Button("Add Songs") { isPicking = true }
    .mediaPicker(isPresented: $isPicking) { songs in
        Task { try await library.add(songs, to: playlist) }
    }
```

## Playback

```swift
let player = MPMusicPlayerController.applicationMusicPlayer
player.setQueue(with: songs, startingAt: tappedSong)
player.play()

player.playNext([song])     // after the current song
player.playLater([song])    // at the end of the queue
```

`@NowPlaying` follows the player in `\.musicPlayer` (the app's own player by default):

```swift
struct MiniPlayer: View {
    @NowPlaying var song
    @Environment(\.musicPlayer) private var player

    var body: some View {
        if let song {
            Text(song.title ?? "")
            Button($song.isPlaying ? "Pause" : "Play") {
                $song.isPlaying ? player.pause() : player.play()
            }
        }
    }
}

#Preview {
    MiniPlayer().musicPlayer(.preview(queue: previewSongs, state: .playing))
}
```

## Previews

```swift
#Preview(traits: .musicLibrary(songs: previewSongs)) {   // iOS 18+
    SongList()
}

#Preview {
    SongList()
        .musicLibrary(.accessDenied)
}
```

## Migration

### 1.0.0

1.0 keeps one way to do each thing, so everything deprecated and the MediaPlayer-type shortcuts
are gone:

| Before | 1.0 |
|---|---|
| `library.songs()` | `library.fetch(.songs)` |
| `library.songs(sortedBy: \MPMediaItem.playCount, order: .reverse)` | `library.fetch(.songs.sorted(by: \.playCount, .reverse))` |
| `library.songs(matching: .artist("Adele"), comparisonType: .equalTo)` | `library.fetch(.songs.filter(\.artist == "Adele"))` |
| `library.albums()`, `artists()`, `playlists()`, `genres()`, `composers()`, `podcasts()`, `compilations()` | `library.fetch(.albums)`, `.artists`, `.playlists`, `.genres`, `.composers`, `.podcasts`, `.compilations` |
| `library.audiobooks()` | `library.fetch(.audiobooks)` |
| `library.fetchAll(type, groupingType:)`, `mediaItems(ofType:…)`, `mediaItemCollections(ofType:…)` | `library.items(MediaQueryRequest(…))`, `library.collections(MediaQueryRequest(…))` |
| `library.songSections()`, `albumSections()`, `artistSections()` | `library.sections(.songs)`, `.albums`, `.artists` |
| `SortKey`, `FlagKey` | Sort by any key path: `.sorted(by: \.isExplicit)` |
| `AuthorizationManagerError.unauthorized(status)` | `MusicLibraryError.unauthorized(status)` |
| Errors from custom services or MediaPlayer | `MusicLibraryError.underlying(error)` |
| Your own `@Entry var library` | `@Environment(\.musicLibrary)` and `.musicLibrary(_:)` |
| `PreviewMusicLibrary`, `.preview(fetchedSongs:…)` | `.preview(songs:albums:artists:playlists:)` |
| `request.filter` | `request.filters` |

MediaBridge no longer makes `Optional` conform to `Comparable` in your module; queries sort
optional key paths themselves, with missing values first.

## Documentation

For more information visit [Documentation](https://swiftpackageindex.com/kolomiiets-oleksii/MediaBridge/documentation/mediabridge).

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to MediaBridge.

## License

MIT License - see the [LICENSE](LICENSE) file for details.
