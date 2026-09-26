import Combine
import Foundation

@MainActor
final class MediaQueryLoader<Element: LibraryElement>: ObservableObject {
    @Published private(set) var elements: [Element] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: MusicLibraryError?

    private var query: LibraryQuery<Element>?
    private var library: (any MusicLibraryProtocol)?
    private var libraryIdentity: ObjectIdentifier?
    private var loadTask: Task<Void, Never>?
    private var loadCancellable: AnyCancellable?
    private var changesCancellable: AnyCancellable?

    func update(query: LibraryQuery<Element>, library: any MusicLibraryProtocol) {
        let identity = Self.identity(of: library)
        let libraryChanged = identity != libraryIdentity
        guard libraryChanged || query != self.query else { return }

        self.query = query
        self.library = library
        libraryIdentity = identity
        if libraryChanged {
            observeChanges(of: library)
        }
        load()
    }

    func reload() async {
        load()
        await settle()
    }

    func settle() async {
        await loadTask?.value
    }

    private func load() {
        guard let query, let library else { return }
        loadTask?.cancel()
        let task = Task { [weak self] in
            self?.isLoading = true
            do throws(MusicLibraryError) {
                let elements = try await library.fetch(query)
                guard !Task.isCancelled else { return }
                self?.elements = elements
                self?.error = nil
            } catch {
                guard !Task.isCancelled else { return }
                self?.error = error
            }
            self?.isLoading = false
        }
        loadTask = task
        loadCancellable = AnyCancellable { task.cancel() }
    }

    private func observeChanges(of library: any MusicLibraryProtocol) {
        let task = Task { [weak self] in
            for await _ in library.changes {
                self?.load()
            }
        }
        changesCancellable = AnyCancellable { task.cancel() }
    }

    private static func identity(of library: any MusicLibraryProtocol) -> ObjectIdentifier {
        type(of: library) is AnyClass ? ObjectIdentifier(library as AnyObject) : ObjectIdentifier(type(of: library))
    }
}
