import SwiftUI

/// Fetches a ``LibraryQuery`` for a SwiftUI view and keeps it current, like SwiftData's `@Query`.
///
/// The query runs against ``SwiftUICore/EnvironmentValues/musicLibrary`` when the view appears, again
/// whenever the query changes, and whenever the music library changes. The first fetch asks for
/// access if the user hasn't decided yet.
///
/// ```swift
/// struct SongList: View {
///     @MediaQuery(.songs.sorted(by: \.title)) var songs
///
///     var body: some View {
///         List(songs) { song in
///             Text(song.title ?? "")
///         }
///         .overlay {
///             if let error = $songs.error {
///                 Text(error.localizedDescription)
///             }
///         }
///         .refreshable { await $songs.reload() }
///     }
/// }
/// ```
///
/// Name the queries your app repeats, and use them the same way:
///
/// ```swift
/// extension LibraryQuery where Element == Song {
///     static var mostSkipped: Self { .songs.filter(\.skipCount > 0).sorted(by: \.skipCount, .reverse) }
/// }
///
/// @MediaQuery(.mostSkipped) var songs
/// ```
///
/// To change the query at runtime, pass it in from the view's initializer:
///
/// ```swift
/// init(order: SortOrder) {
///     _songs = MediaQuery(.songs.sorted(by: \.skipCount, order))
/// }
/// ```
@MainActor
@propertyWrapper
public struct MediaQuery<Element: LibraryElement>: @preconcurrency DynamicProperty {
    @Environment(\.musicLibrary) private var library
    @StateObject private var loader = MediaQueryLoader<Element>()
    private let query: LibraryQuery<Element>

    public init(_ query: LibraryQuery<Element>) {
        self.query = query
    }

    /// The query's results; empty until the first fetch finishes.
    public var wrappedValue: [Element] {
        loader.elements
    }

    /// Loading state, the last error, and reloading, as `$songs.isLoading` and friends.
    public var projectedValue: Status {
        Status(isLoading: loader.isLoading, error: loader.error, loader: loader)
    }

    public func update() {
        loader.update(query: query, library: library)
    }

    /// The loading state of a ``MediaQuery``.
    @MainActor
    public struct Status {
        /// Whether a fetch is in progress.
        public let isLoading: Bool
        /// Why the last fetch failed, or `nil` after a success.
        public let error: MusicLibraryError?
        let loader: MediaQueryLoader<Element>

        /// Fetches again and returns when the results are in, for `.refreshable`.
        public func reload() async {
            await loader.reload()
        }
    }
}
