#if canImport(UIKit)
    import UIKit

    /// Rendered artwork kept on disk between launches.
    ///
    /// MediaPlayer keeps about 1.3 to 2 MB for every distinct album it renders in a process, and
    /// never gives it back. An album read from here is not rendered again, so it costs MediaPlayer
    /// nothing. A struct of closures, so a test hands the cache an in-memory store.
    struct ArtworkDisk: Sendable {
        var load: @Sendable (ArtworkRequest) -> UIImage?
        /// Called with the image MediaPlayer rendered. Returns at once; writing happens elsewhere.
        var save: @Sendable (UIImage, ArtworkRequest) -> Void

        /// Nothing is stored.
        static let none = ArtworkDisk(load: { _ in nil }, save: { _, _ in })

        /// Thumbnails as JPEG files in the Caches directory, which the system may empty when the
        /// device is short of storage. Oldest files go first once `byteLimit` is passed. A file older
        /// than `maxAge` is removed instead of read, so artwork the user changed in the library is
        /// rendered again within that time.
        static func live(
            directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MediaBridge/Artwork", isDirectory: true),
            byteLimit: Int = 64 << 20,
            pendingByteLimit: Int = 24 << 20,
            maxAge: TimeInterval = 30 * 24 * 60 * 60,
            now: @escaping @Sendable () -> Date = { Date() }
        ) -> ArtworkDisk {
            let store = FileStore(
                directory: directory, byteLimit: byteLimit, pendingByteLimit: pendingByteLimit,
                maxAge: maxAge, now: now)
            return ArtworkDisk(load: { store.load($0) }, save: { store.save($0, for: $1) })
        }
    }

    private final class FileStore: @unchecked Sendable {
        private let directory: URL
        private let byteLimit: Int
        private let pendingByteLimit: Int
        private let maxAge: TimeInterval
        private let now: @Sendable () -> Date
        private let lock = NSLock()
        /// Decoded size of the images waiting for the writer. MediaPlayer hands out 1170 px images
        /// faster than they are encoded; unbounded, the waiting images were 1.2 GB on a device.
        private var pendingBytes = 0
        /// One writer at a time: encoding thumbnails side by side would raise the peak footprint.
        private let queue = DispatchQueue(label: "MediaBridge.ArtworkDisk.write", qos: .utility)

        init(
            directory: URL, byteLimit: Int, pendingByteLimit: Int, maxAge: TimeInterval,
            now: @escaping @Sendable () -> Date
        ) {
            self.maxAge = maxAge
            self.now = now
            self.directory = directory
            self.byteLimit = byteLimit
            self.pendingByteLimit = pendingByteLimit
        }

        private func url(for request: ArtworkRequest) -> URL {
            directory.appendingPathComponent("\(request.id.kind)-\(request.id.id)-\(Int(request.side)).jpg")
        }

        func load(_ request: ArtworkRequest) -> UIImage? {
            guard request.id.id != 0 else { return nil }
            let file = url(for: request)
            if let written = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                now().timeIntervalSince(written) > maxAge
            {
                try? FileManager.default.removeItem(at: file)
                return nil
            }
            return UIImage(contentsOfFile: file.path)
        }

        func save(_ image: UIImage, for request: ArtworkRequest) {
            guard request.id.id != 0 else { return }
            let target = url(for: request)
            // Over the limit the image is dropped, not kept waiting: it is saved the next time the
            // album renders in a later launch.
            // 4 bytes a pixel.
            let cost = Int(image.size.width * image.scale * image.size.height * image.scale) << 2
            let accepted = lock.withLock { () -> Bool in
                guard pendingBytes + cost <= pendingByteLimit else { return false }
                pendingBytes += cost
                return true
            }
            guard accepted else { return }
            queue.async { [self] in
                defer { lock.withLock { pendingBytes -= cost } }
                // MediaPlayer hands back its own size (1170 px for every request on an iPhone 12 Pro),
                // so scale to what the view shows, at up to 3x, before writing.
                let pixels = CGFloat(request.side * 3)
                let size = image.size
                let scaled =
                    max(size.width * image.scale, size.height * image.scale) > pixels
                    ? image.preparingThumbnail(of: CGSize(width: pixels, height: pixels)) ?? image : image
                guard let data = scaled.jpegData(compressionQuality: 0.85) else { return }
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try? data.write(to: target, options: .atomic)
                trim()
            }
        }

        /// Removes the oldest files until the folder fits `byteLimit`.
        private func trim() {
            let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
            guard
                let files = try? FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: keys)
            else { return }
            var entries = files.compactMap { file -> (URL, Int, Date)? in
                guard let values = try? file.resourceValues(forKeys: Set(keys)),
                    let size = values.fileSize, let date = values.contentModificationDate
                else { return nil }
                return (file, size, date)
            }
            var total = entries.reduce(0) { $0 + $1.1 }
            guard total > byteLimit else { return }
            entries.sort { $0.2 < $1.2 }
            for (file, size, _) in entries where total > byteLimit {
                try? FileManager.default.removeItem(at: file)
                total -= size
            }
        }
    }
#endif
