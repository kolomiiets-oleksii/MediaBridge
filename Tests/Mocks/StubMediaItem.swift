import MediaPlayer

/// An `MPMediaItem` whose properties come from a dictionary keyed by `MPMediaItemProperty…`
/// constants, so tests can sort and filter items without a real music library.
final class StubMediaItem: MPMediaItem, @unchecked Sendable {
    private let values: [String: Any]
    private let lock = NSLock()
    private var readProperties: [String] = []

    init(_ values: [String: Any]) {
        self.values = values
        super.init()
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Every property read through `value(forProperty:)`, in order.
    var reads: [String] { lock.withLock { readProperties } }

    override func value(forProperty property: String) -> Any? {
        lock.withLock { readProperties.append(property) }
        return values[property]
    }

    override var title: String? { values[MPMediaItemPropertyTitle] as? String }
    override var artist: String? { values[MPMediaItemPropertyArtist] as? String }
    override var playCount: Int { values[MPMediaItemPropertyPlayCount] as? Int ?? 0 }
    override var isExplicitItem: Bool { values[MPMediaItemPropertyIsExplicit] as? Bool ?? false }
}

extension StubMediaItem {
    static func song(_ title: String, by artist: String = "Artist", plays: Int = 0, explicit: Bool = false) -> StubMediaItem {
        StubMediaItem([
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlayCount: plays,
            MPMediaItemPropertyIsExplicit: explicit,
        ])
    }
}
