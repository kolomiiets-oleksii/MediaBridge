import MediaBridge
import SwiftUI

/// Top artists by plays, built with `grouped`. In the demo library nothing has been played, so the
/// order falls back to song count.
struct TopArtistsView: View {
    @Environment(\.musicLibrary) private var library
    @State private var artists: [LibraryGroup<String?, Song>] = []
    @State private var error: MusicLibraryError?

    var body: some View {
        List(artists, id: \.key) { artist in
            HStack {
                VStack(alignment: .leading) {
                    Text(artist.key ?? "Unknown Artist")
                    Text("^[\(artist.count) song](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(artist.sum(of: \.playCount), format: .number).font(.headline).monospacedDigit()
                    // Plays times length is how long you've listened.
                    Text(listening(artist), format: .units(allowed: [.hours, .minutes], width: .narrow))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if let error {
                ContentUnavailableView("Can't Load Artists", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription))
            } else if artists.isEmpty {
                ContentUnavailableView("No Artists", systemImage: "music.mic")
            }
        }
        .navigationTitle("Top Artists")
        .task { await load() }
    }

    private func listening(_ artist: LibraryGroup<String?, Song>) -> Duration {
        let seconds: Double = artist.sum(of: { $0.duration * Double($0.playCount) })
        return .seconds(seconds)
    }

    private func load() async {
        do throws(MusicLibraryError) {
            artists = try await library.grouped(.songs, by: \.artist)
                .sorted { ($0.sum(of: \.playCount), $0.count) > ($1.sum(of: \.playCount), $1.count) }
                .prefix(20)
                .map { $0 }
            error = nil
        } catch {
            self.error = error
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { TopArtistsView() }
        .musicLibrary(.preview(songs: DemoSongs.all))
}
#endif
