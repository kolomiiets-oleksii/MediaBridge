import MediaBridge
import MediaPlayer
import SwiftUI

struct SkippedSongList: View {
    private static let mostSkippedID = UUID(uuidString: "5E1F3C1A-7A43-4E0B-9B8F-2D6C0F1E4A11")!

    @Environment(\.musicLibrary) private var library
    @Environment(\.openURL) private var openURL
    @MediaQuery private var songs: [Song]
    @State private var error: MusicLibraryError?
    @State private var errorTitle = ""
    @State private var isShowingError = false
    @State private var isSaving = false
    @State private var savedCount = 0
    @State private var isShowingSaved = false

    init(order: SortOrder) {
        _songs = MediaQuery(.songs.sorted(by: \.skipCount, order).then(by: \.title))
    }

    var body: some View {
        List(songs) { song in
            SongRow(song: song)
        }
        .overlay {
            if $songs.isLoading && songs.isEmpty {
                ProgressView()
            } else if songs.isEmpty {
                ContentUnavailableView("No Songs", systemImage: "music.note")
            }
        }
        .refreshable { await $songs.reload() }
        .toolbar {
            Button("Save as Playlist", systemImage: "text.badge.plus") {
                Task { await saveMostSkipped() }
            }
            .disabled(isSaving || songs.isEmpty)
        }
        .onChange(of: $songs.error) { _, error in
            guard let error else { return }
            show(error, title: "Can't Load Songs")
        }
        .alert("Most Skipped", isPresented: $isShowingSaved) {
            Button("OK") {}
        } message: {
            Text(savedCount == 0 ? "The playlist is up to date." : "Added ^[\(savedCount) song](inflect: true) to the playlist.")
        }
        .alert(errorTitle, isPresented: $isShowingError, presenting: error) { error in
            if error == .unauthorized(.denied) {
                Button("Open Settings") {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func saveMostSkipped() async {
        isSaving = true
        defer { isSaving = false }

        do throws(MusicLibraryError) {
            let playlist = try await library.playlist(
                id: Self.mostSkippedID,
                orCreate: PlaylistMetadata(name: "Most Skipped", descriptionText: "The songs you skip the most.")
            )
            let saved = Set(playlist.songs.map(\.id))
            let mostSkipped = try await library.fetch(.songs.filter(\.skipCount > 0).sorted(by: \.skipCount, .reverse).limit(25))
            let new = mostSkipped.filter { !saved.contains($0.id) }
            try await library.add(new, to: playlist)
            savedCount = new.count
            isShowingSaved = true
        } catch {
            show(error, title: "Can't Save Playlist")
        }
    }

    private func show(_ error: MusicLibraryError, title: String) {
        self.error = error
        errorTitle = title
        isShowingError = true
    }
}
