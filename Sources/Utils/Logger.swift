import Foundation
import OSLog

internal let log: Logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "media-bridge",
    category: "MediaBridge"
)
