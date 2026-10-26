#if canImport(UIKit)
    import UIKit

    /// Decoded artwork, kept in memory by persistent ID and rendered size.
    ///
    /// MediaPlayer caches the image itself, but not decoded for display and not per cell, so
    /// without this a `LazyVGrid` row scrolled away and back decodes its artwork again.
    final class ArtworkCache: @unchecked Sendable {
        static let shared = ArtworkCache()

        // NSCache is thread-safe, and evicts on memory pressure by itself.
        private let cache = NSCache<NSString, UIImage>()

        init(countLimit: Int = 1_500, byteLimit: Int = 96 * 1024 * 1024) {
            cache.countLimit = countLimit
            cache.totalCostLimit = byteLimit
        }

        func image(for request: ArtworkRequest) -> UIImage? {
            guard let key = Self.key(for: request) else { return nil }
            return cache.object(forKey: key)
        }

        func insert(_ image: UIImage, for request: ArtworkRequest) {
            guard let key = Self.key(for: request) else { return }
            let pixels = image.size.width * image.scale * image.size.height * image.scale
            cache.setObject(image, forKey: key, cost: Int(pixels * 4))
        }

        /// Renders `request` off the main actor, and caches the result.
        ///
        /// `render` is MediaPlayer's `MPMediaItemArtwork.image(at:)` call, so it runs on a
        /// background thread here, followed by the decode for display. Callers asking for the
        /// same request while it renders share that one render. Cancelling a caller cancels the
        /// work, if it hasn't started, only once every caller has cancelled.
        func render(
            _ request: ArtworkRequest, with render: @escaping @Sendable (CGSize) -> UIImage?
        ) async -> UIImage? {
            let size = CGSize(width: request.side, height: request.side)
            guard let key = Self.key(for: request).map({ $0 as String }) else {
                // No persistent ID, so nothing to share or cache.
                return await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    guard !Task.isCancelled else { return nil }
                    return await render(size)?.byPreparingForDisplay()
                }.value
            }

            let flight = lock.withLock { () -> Flight in
                if let running = flights[key] {
                    running.waiters += 1
                    return running
                }
                let flight = Flight()
                flights[key] = flight
                flight.task = Task.detached(priority: .userInitiated) { [self] () -> UIImage? in
                    guard !Task.isCancelled else { return finish(key, flight, nil, request) }
                    let image = await render(size)?.byPreparingForDisplay()
                    return finish(key, flight, image, request)
                }
                return flight
            }
            return await withTaskCancellationHandler {
                await flight.task.value
            } onCancel: {
                lock.withLock {
                    flight.waiters -= 1
                    if flight.waiters == 0 {
                        flight.task.cancel()
                        if flights[key] === flight { flights[key] = nil }
                    }
                }
            }
        }

        private final class Flight: @unchecked Sendable {
            var task: Task<UIImage?, Never>!
            var waiters = 1
        }

        private let lock = NSLock()
        private var flights: [String: Flight] = [:]

        private func finish(_ key: String, _ flight: Flight, _ image: UIImage?, _ request: ArtworkRequest) -> UIImage? {
            if let image { insert(image, for: request) }
            lock.withLock { if flights[key] === flight { flights[key] = nil } }
            return image
        }

        // Items without a persistent ID (test doubles) would all share one entry.
        private static func key(for request: ArtworkRequest) -> NSString? {
            guard request.id.id != 0 else { return nil }
            return "\(request.id.kind)-\(request.id.id)-\(Int(request.side))" as NSString
        }
    }
#endif
