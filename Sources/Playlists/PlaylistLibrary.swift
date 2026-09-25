import MediaPlayer

protocol PlaylistLibrary: AnyObject {
    func getPlaylist(
        with uuid: UUID,
        creationMetadata: MPMediaPlaylistCreationMetadata?,
        completionHandler: @escaping @Sendable (MPMediaPlaylist?, Error?) -> Void
    )
}

extension MPMediaLibrary: PlaylistLibrary {}
