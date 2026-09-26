import MediaPlayer

extension LibraryQuery where Element == Song {
    /// Every song, to refine with `filter`, `sorted`, and `limit`: `.songs.sorted(by: \.title)`.
    public static var songs: Self { Song.query }
    /// Every podcast episode, across podcasts.
    public static var podcastEpisodes: Self { Song.query.mediaType(.podcast) }
    /// Every audiobook.
    public static var audiobooks: Self { Song.query.mediaType(.audioBook) }
}

extension LibraryQuery where Element == Album {
    /// Every album.
    public static var albums: Self { Album.query }
    /// Every album marked as a compilation.
    public static var compilations: Self { Album.query.filter(\.isCompilation == true) }
}

extension LibraryQuery where Element == Artist {
    /// Every artist.
    public static var artists: Self { Artist.query }
}

extension LibraryQuery where Element == Genre {
    /// Every genre.
    public static var genres: Self { Genre.query }
}

extension LibraryQuery where Element == Composer {
    /// Every composer.
    public static var composers: Self { Composer.query }
}

extension LibraryQuery where Element == Playlist {
    /// Every playlist.
    public static var playlists: Self { Playlist.query }
}

extension LibraryQuery where Element == Podcast {
    /// Every podcast.
    public static var podcasts: Self { Podcast.query }
}
