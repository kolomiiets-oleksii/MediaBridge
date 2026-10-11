import MediaBridge
import SwiftUI

struct ContentView: View {
    @State private var order: SortOrder = .reverse

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-benchmark") {
            BenchmarkView()
        } else {
            songs
        }
    }

    private var songs: some View {
        NavigationStack {
            SkippedSongList(order: order)
                .navigationTitle("Skipped Songs")
                .toolbar {
                    Button("Sort", systemImage: "arrow.up.arrow.down") {
                        order = order == .forward ? .reverse : .forward
                    }
                }
        }
    }
}

#Preview("Songs") {
    ContentView()
        .musicLibrary(.preview(songs: DemoSongs.all))
}

#Preview("Access denied") {
    ContentView()
        .musicLibrary(.accessDenied)
}
