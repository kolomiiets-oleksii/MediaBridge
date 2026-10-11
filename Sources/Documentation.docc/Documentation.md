# ``MediaBridge``

@Metadata {
    @PageImage(purpose: icon, source:"media_bridge_logo")
    @SupportedLanguage(swift)
    @PageColor(orange)
}

The user's music library in modern Swift: typed models, key-path queries, typed errors, and a SwiftUI property wrapper.

## Overview

MediaBridge wraps MediaPlayer's library in value types you query with key paths. It asks for access on the first fetch, runs the filters MediaPlayer supports inside its own query, and never copies or stores what it fetches, so large libraries stay fast.

The library is a bridge: ``MusicLibraryProtocol`` is what your code uses, and ``MusicLibraryServiceProtocol`` is the MediaPlayer layer underneath, which you can replace in tests.

### Before You Start

Add `NSAppleMusicUsageDescription` to your app's Info.plist with a sentence explaining why you need the music library. iOS terminates the app on the first library access without it.

```xml
<key>NSAppleMusicUsageDescription</key>
<string>Shows your songs so you can find the ones you skip most.</string>
```

### SwiftUI

``MediaQuery`` fetches for a view and keeps the results current when the query or the library changes:

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
        .overlay {
            if let error = $songs.error {
                Text(error.localizedDescription)
            }
        }
        .refreshable { await $songs.reload() }
    }
}
```

It reads the library from the `musicLibrary` environment value, which defaults to the device's library. Set another one, such as a preview library, with `.musicLibrary(_:)`.

Name the queries your app repeats, and use them anywhere a query goes:

```swift
extension LibraryQuery where Element == Song {
    static var mostSkipped: Self { .songs.filter(\.skipCount > 0).sorted(by: \.skipCount, .reverse) }
}

@MediaQuery(.mostSkipped) var songs
```

### Queries

A ``LibraryQuery`` starts from `.songs`, `.albums`, `.artists`, `.genres`, `.composers`, `.playlists`, `.podcasts`, `.podcastEpisodes`, `.audiobooks`, or `.compilations`, and is refined with filters, orderings, and a limit:

```swift
let library = MusicLibrary()

let topLocal = try await library.fetch(
    .songs
        .filter(\.isCloudItem == false)
        .filter(\.playCount >= 10)
        .sorted(by: \.playCount, .reverse)
        .then(by: \.title)
        .limit(25)
)

let adele = try await library.fetch(.albums.filter(\.artist == "Adele"))
let sections = try await library.sections(.artists)   // A–Z, like the Music app
```

`==` on a property MediaPlayer can filter and `.contains` run inside MediaPlayer's query; every other condition runs in memory. Sorting reads each key once per element.

Combine conditions with `&&`, `||` and `!`, and use `.hasPrefix` and `.isIn` for strings and sets:

```swift
let wanted = try await library.fetch(
    .songs.filter(\.artist == "Adele" || \.artist == "Sade").filter(!(\.isExplicit)))
let a = try await library.fetch(.songs.filter(\.title, .hasPrefix("a")))
let some = try await library.fetch(.songs.filter(\.genre, .isIn(["Jazz", "Blues"])))
```

`&&` keeps each side inside MediaPlayer's query when it can. MediaPlayer can't express "or" or "not", so a query that uses them fetches everything the rest of the query allows and tests those in memory.

### Stats

Group songs by any property and total over each group, for top artists, listening time, or a year in review:

```swift
let artists = try await library.grouped(.songs, by: \.artist)
    .sorted { $0.sum(of: \.playCount) > $1.sum(of: \.playCount) }

let hours = artists[0].sum(of: { $0.duration * Double($0.playCount) }) / 3600
```

Split a list by something other than the first letter, such as the month songs were added:

```swift
let byMonth = try await library.sections(
    .songs.sorted(by: \.dateAdded, .reverse),
    by: \.dateAdded,
    title: { $0?.formatted(.dateTime.year().month(.wide)) })
```

MediaPlayer keeps only a song's lifetime play count, so "plays this month" has no direct answer. ``PlayCountHistory`` records the counts as you launch the app and subtracts, **counting only from the first time it records**:

```swift
let history = PlayCountHistory()
try await history.record(from: library)       // at launch and when the app returns to the foreground

let plays = try await history.plays(since: monthStart)          // persistent ID → plays this month
let thisMonth = try await library.grouped(.songs, by: \.artist)
    .sorted { $0.sum(of: { plays[$0.id] ?? 0 }) > $1.sum(of: { plays[$0.id] ?? 0 }) }
```

Outside a SwiftUI view, stream a query with `results(_:)`: it yields the results now and again after each change to the library, which `@MediaQuery` runs on:

```swift
for await result in library.results(.songs.sorted(by: \.title)) {
    switch result {
    case .success(let songs): self.songs = songs
    case .failure(let error): self.error = error
    }
}
```

A failed fetch arrives as a `.failure` and the stream keeps going. A burst of library changes, such as the play count and last played date updating as a song plays, causes one refetch.

Each model keeps its MediaPlayer object, such as `song.mediaItem`, for other MediaPlayer APIs. Artwork is rendered on demand, off the main thread, and kept in an in-memory cache; ``ArtworkImage`` loads it when it appears, with a placeholder you can replace:

```swift
ArtworkImage(song, size: 48, cornerRadius: 4)
    .placeholder { Image("logo").resizable().padding(8) }
```

Leave out the size and it fills the width the layout offers, such as a grid cell, and renders at that size:

```swift
ArtworkImage(album, cornerRadius: 8)
```

### Playback

Queue songs on any `MPMusicPlayerController`, or any ``MusicPlayerProtocol``:

```swift
let player = MPMusicPlayerController.applicationMusicPlayer
player.setQueue(with: songs, startingAt: tappedSong)
player.play()

player.playNext([song])     // after the current song
player.playLater([song])    // at the end of the queue
```

``NowPlaying`` follows the player in the `musicPlayer` environment value, which defaults to `applicationMusicPlayer`:

```swift
struct MiniPlayer: View {
    @NowPlaying var song

    var body: some View {
        if let song {
            Label(song.title ?? "", systemImage: $song.isPlaying ? "play.fill" : "pause.fill")
        }
    }
}
```

A progress bar needs no polling. `$song.position` says where playback was and how fast it moves, and `TimelineView` asks for the time as often as you like:

```swift
TimelineView(.periodic(from: .now, by: 0.5)) { context in
    Slider(
        value: Binding(
            get: { $song.position.time(at: context.date, clampedTo: song.duration) },
            set: { $song.seek(to: $0) }),
        in: 0...song.duration)
}
```

`$song.repeatMode`, `$song.shuffleMode`, and the `setRepeatMode(_:)` and `setShuffleMode(_:)` methods next to them cover the rest of a player's controls. MediaPlayer sends no notification when repeat or shuffle change, so a change made elsewhere shows up when your app becomes active.

`MPMusicPlayerController.applicationQueuePlayer` is the one player that can read its queue, so only it fills `$song.queue`, `$song.queueIndex`, and `$song.upNext`. It can also remove songs: `try await player.removeFromQueue(songs)`.

In previews, `.musicPlayer(.preview(queue:state:))` supplies a ``PreviewMusicPlayer`` that keeps its queue in memory.

### Errors

Every call throws ``MusicLibraryError``, so `catch` blocks match its cases without casting:

```swift
do {
    songs = try await library.fetch(.songs)
} catch .unauthorized(.denied) {
    showSettingsButton = true
} catch {
    message = error.localizedDescription
}
```

### Playlists and Picking Songs

Your app can create its own playlists and add songs to them. Generate the UUID once and keep it: the same UUID always returns the same playlist, which also appears in the Music app.

```swift
let playlist = try await library.playlist(
    id: mostSkippedID,
    orCreate: PlaylistMetadata(name: "Most Skipped", descriptionText: "Songs I skip")
)
try await library.add(songs, to: playlist)
```

MediaPlayer can't remove songs from a playlist, and only playlists your app created can be changed.

With Apple Music, you can also add catalog songs, albums, and playlists by their product ID, to the library or to your playlist. Nothing can remove them from the library afterwards.

```swift
let added = try await library.add(productID: "1440839718")
try await library.add(productID: "1440839718", to: playlist)
```

To let people choose songs themselves, present the system picker (iOS only):

```swift
Button("Add Songs") { isPicking = true }
    .mediaPicker(isPresented: $isPicking) { songs in
        Task { try await library.add(songs, to: playlist) }
    }
```

### Previews

In debug builds, `.preview(...)` builds a ``MusicLibrary`` backed by fixed data, and presets such as `.accessDenied` cover each authorization state. Queries, sorting, and the authorization flow run through the real library, and songs are grouped into albums, artists, genres, and composers when you don't pass collections:

```swift
#Preview(traits: .musicLibrary(songs: previewSongs)) {   // iOS 18 and later
    SongList()
}

#Preview("Denied") {
    SongList()
        .musicLibrary(.accessDenied)
}
```

### Service Layer

``MusicLibrary`` handles authorization, typed models, filtering, and sorting on top of a service that runs ``MediaQueryRequest``s. Replace the service to serve fixtures in tests:

```swift
struct FixtureService: MusicLibraryServiceProtocol {
    let songs: [MPMediaItem]
    func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] { songs }
    func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] { [] }
}

let library = MusicLibrary(service: FixtureService(songs: fixtures))
```

``MusicLibraryProtocol/items(_:)`` and ``MusicLibraryProtocol/collections(_:)`` run a request directly and return MediaPlayer's own types, for anything the typed queries don't cover.

## Topics

### SwiftUI
- ``MediaQuery``
- ``NowPlaying``
- ``ArtworkImage``
- ``MediaPicker``

### Models
- ``Song``
- ``Album``
- ``Artist``
- ``Genre``
- ``Composer``
- ``Playlist``
- ``Podcast``

### Queries
- ``LibraryQuery``
- ``LibraryCondition``
- ``LibraryPredicate``
- ``LibraryGroup``
- ``LibraryElement``
- ``CollectionElement``
- ``MediaSection``

### Play History
- ``PlayCountHistory``
- ``PlayCountStore``
- ``FilePlayCountStore``
- ``InMemoryPlayCountStore``
- ``PlayCountSnapshot``

### The Library
- ``MusicLibrary``
- ``MusicLibraryProtocol``
- ``MusicLibraryError``
- ``PlaylistMetadata``

### Playback
- ``MusicPlayerProtocol``
- ``PlaybackPosition``
- ``PreviewMusicPlayer``

### Library Changes
- ``LibraryChangesProtocol``
- ``LiveLibraryChanges``
- ``MediaLibraryChangeTracking``

### Service Layer
- ``MusicLibraryServiceProtocol``
- ``MusicLibraryService``
- ``MediaQueryRequest``
- ``MediaQueryProtocol``
- ``MediaItemPredicateInfo``

### Authorization
- ``AuthorizationManagerProtocol``
- ``AuthorizationManager``
- ``MediaLibraryProtocol``
