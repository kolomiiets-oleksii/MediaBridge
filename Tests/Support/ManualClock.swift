import Foundation

@testable import MediaBridge

/// A clock that stands still until the test calls `advance(by:)`. Sleepers whose time has come
/// wake on `advance`; a cancelled sleeper wakes at once with `CancellationError`.
@MainActor
final class ManualClock {
    private(set) var now = Date(timeIntervalSinceReferenceDate: 0)
    private struct Sleeper {
        let deadline: Date
        let wake: CheckedContinuation<Void, any Error>
    }

    private var sleepers: [UUID: Sleeper] = [:]

    var loaderClock: LoaderClock {
        LoaderClock(now: { [self] in now }, sleep: { [self] seconds in try await sleep(seconds) })
    }

    var pendingSleepers: Int { sleepers.count }

    /// Returns once `count` sleepers are waiting. No time passes.
    func untilSleeping(_ count: Int = 1) async {
        while sleepers.count < count { await Task.yield() }
    }

    /// Lets work already started reach its sleep, moves time forward, wakes every sleeper that is
    /// now due, and lets the woken work run.
    func advance(by seconds: TimeInterval) async {
        await settle()
        now += seconds
        let due = sleepers.filter { $0.value.deadline <= now }.sorted { $0.value.deadline < $1.value.deadline }
        for (id, sleeper) in due {
            sleepers[id] = nil
            sleeper.wake.resume()
        }
        await settle()
    }

    private func sleep(_ seconds: TimeInterval) async throws {
        let id = UUID()
        let deadline = now + seconds
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                enqueue(Sleeper(deadline: deadline, wake: continuation), id: id)
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    private func enqueue(_ sleeper: Sleeper, id: UUID) {
        if Task.isCancelled {
            sleeper.wake.resume(throwing: CancellationError())
        } else if sleeper.deadline <= now {
            sleeper.wake.resume()
        } else {
            sleepers[id] = sleeper
        }
    }

    private func cancel(_ id: UUID) {
        sleepers.removeValue(forKey: id)?.wake.resume(throwing: CancellationError())
    }
}

/// Lets the main actor run the work already queued on it, and the work that work queues, a
/// bounded number of turns. No time passes.
@MainActor
func settle(turns: Int = 100) async {
    for _ in 0..<turns { await Task.yield() }
}
