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

        init(countLimit: Int = 600, byteLimit: Int = 48 * 1024 * 1024) {
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
        /// background thread here, followed by the decode for display. Cancelling the caller
        /// cancels the work if it hasn't started.
        func render(
            _ request: ArtworkRequest, with render: @escaping @Sendable (CGSize) -> UIImage?
        ) async -> UIImage? {
            let size = CGSize(width: request.side, height: request.side)
            let work = Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard !Task.isCancelled else { return nil }
                return await render(size)?.byPreparingForDisplay()
            }
            let image = await withTaskCancellationHandler {
                await work.value
            } onCancel: {
                work.cancel()
            }
            if let image { insert(image, for: request) }
            return image
        }

        // Items without a persistent ID (test doubles) would all share one entry.
        private static func key(for request: ArtworkRequest) -> NSString? {
            guard request.id.id != 0 else { return nil }
            return "\(request.id.kind)-\(request.id.id)-\(Int(request.side))" as NSString
        }
    }
#endif
