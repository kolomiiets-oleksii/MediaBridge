import MediaBridge
import MediaPlayer
import SwiftUI

struct ContentView: View {
    @Environment(\.library) private var library
    @Environment(\.openURL) private var openURL
    @State private var songs: [Song] = []
    @State private var order: SortOrder = .reverse
    @State private var isLoading = true
    @State private var error: Error?
    @State private var isShowingError = false

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
                Button("Sort", systemImage: "arrow.up.arrow.down") {
                    order = order == .forward ? .reverse : .forward
                }
                .disabled(isLoading)
            }
            .alert("Can't Load Songs", isPresented: $isShowingError, presenting: error) { error in
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

    private func loadSongs() async {
        isLoading = true
        defer { isLoading = false }

        do {
            songs = try await library.fetch(Song.query.sorted(by: \.skipCount, order).then(by: \.title))
        } catch {
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
