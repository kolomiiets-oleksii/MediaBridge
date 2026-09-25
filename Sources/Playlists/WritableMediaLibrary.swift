import MediaPlayer

protocol WritableMediaLibrary: AnyObject {
    func getPlaylist(
        with uuid: UUID,
        creationMetadata: MPMediaPlaylistCreationMetadata?,
        completionHandler: @escaping @Sendable (MPMediaPlaylist?, Error?) -> Void
    )

    func addItem(withProductID productID: String, completionHandler: (@Sendable ([MPMediaEntity], Error?) -> Void)?)
}

extension MPMediaLibrary: WritableMediaLibrary {}
