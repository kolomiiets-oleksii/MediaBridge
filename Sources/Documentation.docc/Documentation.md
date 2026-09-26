# ``MediaBridge``

@Metadata {
    @PageImage(purpose: icon, source:"media_bridge_logo")
    @SupportedLanguage(swift)
    @PageColor(orange)
}

A Swift bridge for MPMediaLibrary integration. Provides easy, lightweight and flexible methods to fetch media library content from your phone.

## Overview

MediaBridge simplifies access to the device's music library with a clean API that handles authorization automatically: the first fetch shows the system prompt if the user hasn't decided yet. It's built on two core components: a service layer for querying and an authorization manager for permissions.

### Before You Start

Add `NSAppleMusicUsageDescription` to your app's Info.plist with a sentence explaining why you need the music library. iOS terminates the app on the first library access without it.

```xml
<key>NSAppleMusicUsageDescription</key>
<string>Shows your songs so you can find the ones you skip most.</string>
```

### Querying with Models

``Song``, ``Album``, ``Artist``, ``Genre``, and ``Playlist`` wrap MediaPlayer objects without copying them, so fetching a large library costs no property reads. Describe what you want with a ``LibraryQuery`` and run it with ``MusicLibraryProtocol/fetch(_:)``:

```swift
let mostPlayed = try await library.fetch(
    Song.query
        .filter(\.isCloudItem, .equals(false))
        .filter(\.playCount, .atLeast(10))
        .sorted(by: \.playCount, .reverse)
        .then(by: \.title)
        .limit(25)
)

let adeleAlbums = try await library.fetch(Album.query.filter(\.artist, .equals("Adele")))
```

Filters MediaPlayer supports run inside its query; the rest run in memory. Artwork is rendered on demand and never stored:

```swift
List(mostPlayed) { song in
    HStack {
        ArtworkImage(song, size: 44)
        Text(song.title ?? "")
    }
}
```

Each model keeps its MediaPlayer object (`song.mediaItem`) for APIs such as `MPMusicPlayerController`.

### General Usage

Create a `MusicLibrary` and start fetching:

```swift
let library = MusicLibrary()
let songs = try await library.songs()
let albums = try await library.albums()
let artists = try await library.artists()
let playlists = try await library.playlists()
```

Fetch with sorting:

```swift
// Songs sorted by skip count (most skipped first)
let songs = try await library.songs(sortedBy: \MPMediaItem.skipCount, order: .reverse)

// Albums sorted by track count
let albums = try await library.albums(sortedBy: \MPMediaItemCollection.count, order: .reverse)
```

Filter using predicates:

```swift
// Songs by a specific artist
let artistSongs = try await library.songs(matching: .artist("Taylor Swift"), comparisonType: .contains)

// Albums matching a genre
let rockAlbums = try await library.albums(matching: .genre("Rock"), .equalTo, groupingType: .album)

// Playlists matching a name
let chillPlaylists = try await library.playlists(matching: .playlistName("Chill"), .contains)

// Only songs stored on the device
let localSongs = try await library.songs(matching: .isCloudItem(false), comparisonType: .equalTo)
```

Beyond songs, albums, artists, and playlists, there are genres, composers, compilations, podcasts, and audiobooks, plus ``MusicLibraryProtocol/items(_:)`` and ``MusicLibraryProtocol/collections(_:)`` for any ``MediaQueryRequest``:

```swift
let genres = try await library.genres(sortedBy: \MPMediaItemCollection.count, order: .reverse)
let podcasts = try await library.podcasts()
```

Build an A–Z index like the Music app's with sections:

```swift
let sections = try await library.songSections()   // [MediaSection<MPMediaItem>]
```

Refresh when the library changes, for example after a sync:

```swift
.task {
    for await _ in library.changes {
        songs = (try? await library.songs()) ?? []
    }
}
```

Or inject it into SwiftUI views via environment values (`library` is a key your app declares):

```swift
extension EnvironmentValues {
    @Entry var library: MusicLibraryProtocol = MusicLibrary()
}

struct ContentView: View {
    @Environment(\.library) var library

    var body: some View {
        VStack {
            // Use library to fetch songs or albums
        }
        .task {
            // Fetches prompt for access on their own; request up front
            // only to choose when the prompt appears
            if library.authorizationStatus == .notDetermined {
                try? await library.requestAuthorization()
            }
        }
    }
}
```

### Playlists and Picking Songs

Your app can create its own playlists and add songs to them. Generate the UUID once and keep it:
the same UUID always returns the same playlist, which also appears in the Music app.

```swift
let playlist = try await library.playlist(
    id: mostSkippedID,
    orCreate: PlaylistMetadata(name: "Most Skipped", descriptionText: "Songs I skip")
)
try await library.add(songs, to: playlist)
```

MediaPlayer can't remove songs from a playlist, and only playlists your app created can be changed.

With Apple Music, you can also add catalog songs, albums, and playlists by their product ID, to
the library or to your playlist. Nothing can remove them from the library afterwards.

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

### Service Layer & Authorization

Both the service layer and authorization manager use production-ready implementations by default (`.live`), but you can provide custom implementations for testing or specialized behavior.

A service answers ``MediaQueryRequest``s with items or collections; ``MusicLibrary`` builds every call from those two methods, and handles authorization, sorting, and playlist filtering itself:

```swift
struct FixtureService: MusicLibraryServiceProtocol {
    let songs: [MPMediaItem]
    func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] { songs }
    func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] { [] }
}

let library = MusicLibrary(auth: MyAuthorizationManager(), service: FixtureService(songs: fixtures))
```

### SwiftUI Previews

In debug builds, `.preview(...)` builds a ``MusicLibrary`` backed by fixed data, and presets such as `.accessDenied` cover each authorization state. Sorting, filtering, and the authorization flow run through the real library:

```swift
#Preview {
    ContentView()
        .environment(\.library, .preview(songs: previewSongs))
}

#Preview("Denied") {
    ContentView()
        .environment(\.library, .accessDenied)
}
```

## Topics

### Models
- ``Song``
- ``Album``
- ``Artist``
- ``Genre``
- ``Playlist``
- ``ArtworkImage``

### Playlists and Picking
- ``PlaylistMetadata``
- ``MusicLibraryError``
- ``MediaPicker``

### Queries
- ``LibraryQuery``
- ``LibraryCondition``
- ``LibraryElement``

### Fetching Media Items
- ``MusicLibrary``
- ``MusicLibraryProtocol``
- ``MediaSection``

### Library Changes
- ``LibraryChangesProtocol``
- ``LiveLibraryChanges``
- ``MediaLibraryChangeTracking``

### Service Layer
- ``MusicLibraryServiceProtocol``
- ``MediaQueryRequest``
- ``MusicLibraryService``
- ``MediaQueryProtocol``

### Sorting
- ``SortKey``
- ``FlagKey``

### Filtering & Predicates
- ``MediaItemPredicateInfo``

### Authorization
- ``AuthorizationManagerProtocol``
- ``AuthorizationManager``
- ``MediaLibraryProtocol``
- ``AuthorizationManagerError``

