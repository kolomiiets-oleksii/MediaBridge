import MediaBridge
import MediaPlayer
import SwiftUI

struct ContentView: View {
    private static let mostSkippedID = UUID(uuidString: "5E1F3C1A-7A43-4E0B-9B8F-2D6C0F1E4A11")!

    @Environment(\.library) private var library
    @Environment(\.openURL) private var openURL
    @State private var songs: [Song] = []
    @State private var order: SortOrder = .reverse
    @State private var isLoading = true
    @State private var error: Error?
    @State private var errorTitle = ""
    @State private var isShowingError = false
    @State private var isSaving = false
    @State private var savedCount = 0
    @State private var isShowingSaved = false

    var body: some View {
        NavigationStack {
            List(songs) { song in
                SongRow(song: song)
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if songs.isEmpty {
                    ContentUnavailableView("No Songs", systemImage: "music.note")
                }
            }
            .navigationTitle("Skipped Songs")
            .toolbar {
                Button("Save as Playlist", systemImage: "text.badge.plus") {
                    Task { await saveMostSkipped() }
                }
                .disabled(isLoading || isSaving || songs.isEmpty)

                Button("Sort", systemImage: "arrow.up.arrow.down") {
                    order = order == .forward ? .reverse : .forward
                }
                .disabled(isLoading)
            }
            .alert("Most Skipped", isPresented: $isShowingSaved) {
                Button("OK") {}
            } message: {
                Text(savedCount == 0 ? "The playlist is up to date." : "Added ^[\(savedCount) song](inflect: true) to the playlist.")
            }
            .alert(errorTitle, isPresented: $isShowingError, presenting: error) { error in
                if case AuthorizationManagerError.unauthorized(.denied) = error {
                    Button("Open Settings") {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } message: { error in
                Text(error.localizedDescription)
            }
        }
        .task(id: order) {
            await loadSongs()
        }
        .task {
            for await _ in library.changes {
                await loadSongs()
            }
        }
    }

    private func saveMostSkipped() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let playlist = try await library.playlist(
                id: Self.mostSkippedID,
                orCreate: PlaylistMetadata(name: "Most Skipped", descriptionText: "The songs you skip the most.")
            )
            let saved = Set(playlist.songs.map(\.id))
            let mostSkipped = songs.sorted { $0.skipCount > $1.skipCount }.prefix(25)
            let new = mostSkipped.filter { $0.skipCount > 0 && !saved.contains($0.id) }
            try await library.add(Array(new), to: playlist)
            savedCount = new.count
            isShowingSaved = true
        } catch {
            errorTitle = "Can't Save Playlist"
            self.error = error
            isShowingError = true
        }
    }

    private func loadSongs() async {
        isLoading = true
        defer { isLoading = false }

        do {
            songs = try await library.fetch(Song.query.sorted(by: \.skipCount, order).then(by: \.title))
        } catch {
            errorTitle = "Can't Load Songs"
            self.error = error
            isShowingError = true
        }
    }
}

#Preview("Songs") {
    ContentView()
        .environment(\.library, .preview(songs: DemoSongs.all))
}

#Preview("Access denied") {
    ContentView()
        .environment(\.library, .accessDenied)
}
