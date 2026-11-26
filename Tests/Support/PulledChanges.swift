import Foundation

@testable import MediaBridge

/// A change source that counts how often its consumer asks for the next change. A consumer that
/// asks for change `n + 1` has finished handling the first `n`.
final class PulledChanges: LibraryChangesProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var queued = 0
    private var asks = 0
    private var waiter: CheckedContinuation<Date?, Never>?

    var handled: Int { lock.withLock { max(asks - 1, 0) } }

    func changes() -> AsyncStream<Date> {
        AsyncStream(unfolding: { [self] in await next() })
    }

    func fire(times: Int = 1) {
        for _ in 0..<times {
            let waiting: CheckedContinuation<Date?, Never>? = lock.withLock {
                guard let waiter else {
                    queued += 1
                    return nil
                }
                self.waiter = nil
                return waiter
            }
            waiting?.resume(returning: Date())
        }
    }

    /// Returns once the consumer has handled `count` changes. No time passes.
    func untilHandled(_ count: Int) async {
        while handled < count { await Task.yield() }
    }

    private func next() async -> Date? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Date?, Never>) in
                let answer: Date?? = lock.withLock {
                    asks += 1
                    if Task.isCancelled { return .some(nil) }
                    guard queued > 0 else {
                        waiter = continuation
                        return nil
                    }
                    queued -= 1
                    return .some(Date())
                }
                if let answer { continuation.resume(returning: answer) }
            }
        } onCancel: {
            let waiting = lock.withLock {
                defer { waiter = nil }
                return waiter
            }
            waiting?.resume(returning: nil)
        }
    }
}
