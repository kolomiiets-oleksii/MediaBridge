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

### Service Layer & Authorization

Both the service layer and authorization manager use production-ready implementations by default (`.live`), but you can provide custom implementations for testing or specialized behavior:

```swift
let customAuth = MyAuthorizationManager()
let customService = MyMusicLibraryService()
let library = MusicLibrary(auth: customAuth, service: customService)
```

### SwiftUI Previews

In debug builds, ``PreviewMusicLibrary`` stands in for the real library, with presets for each authorization state:

```swift
#Preview {
    ContentView()
        .environment(\.library, .accessDenied)
}
```

## Topics

### Fetching Media Items
- ``MusicLibrary``
- ``MusicLibraryProtocol``

### Service Layer
- ``MusicLibraryServiceProtocol``
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

### Previews
- ``PreviewMusicLibrary``
