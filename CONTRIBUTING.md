# Contributing to MediaBridge

Thank you for your interest in contributing to MediaBridge! We welcome contributions from the community, including code, documentation, bug reports, and feature requests.

## Types of Contributions Welcome

- **Code contributions** - Bug fixes, new features, improvements
- **Documentation** - DocC comments, examples, guides
- **Issue reports** - Bug reports, feature requests, discussions
- **Test improvements** - Better test coverage, more comprehensive tests

## Getting Started

### Prerequisites

- Xcode 16+ with Swift 6.0
- macOS 13+
- Git

### Setup

1. Clone the repository:
```bash
git clone https://github.com/kolomiiets-oleksii/MediaBridge.git
cd MediaBridge
```

2. Build the package:
```bash
swift build
```

3. Run tests:
```bash
swift test
```

4. Generate and view documentation:
```bash
swift package generate-documentation --hosting-base-path MediaBridge
```

## Development Workflow

### Branch Naming

Create feature branches with the format: `{issue-number}-{description}`

Examples:
- `16-add-contributing-file`
- `13-add-docc-to-service-layer`

### Commit Messages

Follow these conventions:
- Use lowercase, imperative mood
- No period at the end
- Be concise and descriptive

Examples:
- `add contributing guidelines`
- `fix authorization manager initialization`
- `improve media query performance`

### Pull Requests

1. Push your branch:
```bash
git push -u origin {branch-name}
```

2. Create a PR with a clear description

3. Include `Closes #{issue-number}` in the PR description to auto-close the issue when merged

4. Ensure all tests pass and address any review feedback

5. After approval, PRs are merged with the merge commit strategy and branch deletion

## Code Standards

### Architecture

MediaBridge follows a **protocol-oriented architecture** with dependency injection:

- All major components have protocol abstractions
- Factory methods provide `.live` for production and `.mock` for testing
- Dependencies are injected via initializers, never as global state

Example pattern:
```swift
protocol MyServiceProtocol {
    func fetchData() async throws -> [Data]
}

extension MyServiceProtocol where Self == MyService {
    public static var live: Self { MyService() }
}

#if DEBUG
extension MyServiceProtocol where Self == MockMyService {
    public static var mock: Self { MockMyService() }
}
#endif
```

### File Organization

1. **Imports** at the top
2. **Protocols** before implementations
3. **MARK comments** for section organization:
   - `// MARK: - General calls`
   - `// MARK: - Specific calls`
   - `// MARK: - Private methods`
   - `// MARK: - ProtocolName Implementation`

### Naming Conventions

- **Types:** PascalCase (e.g., `MusicLibrary`, `AuthorizationManager`)
- **Files:** Match type name exactly (e.g., `MusicLibrary.swift`)
- **Extensions:** Use format `Type+Feature.swift` (e.g., `MPMediaType+Comparable.swift`)
- **Protocols:** Descriptive names ending in `Protocol` (e.g., `MusicLibraryServiceProtocol`)
- **Factory methods:** `.live` for production, `.mock` for testing
- **Properties/Methods:** camelCase (e.g., `songs()`, `authorizationStatus`)

### Code Patterns

1. **No External Dependencies** - Use only iOS frameworks
2. **Async/Await Only** - No completion handlers or callbacks
3. **Modern Swift** - Use Swift 6.0 features including `Sendable` conformance
4. **Minimal Access** - Keep public API surface small and focused
5. **Retroactive Conformance** - Use `@retroactive` attribute for framework type extensions

### Error Handling

- All errors conform to `LocalizedError`
- Use enums with associated values
- Provide meaningful `errorDescription` implementations

Example:
```swift
enum AuthorizationError: LocalizedError {
    case denied
    case notDetermined

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Media library access was denied"
        case .notDetermined:
            return "Media library access status is not determined"
        }
    }
}
```

## Testing Requirements

### Framework

MediaBridge uses **Swift Testing** (not XCTest):

- Import: `import Testing`
- Test suites: `@Suite("Name")`
- Test methods: `@Test func testFeature() async throws`
- Assertions: `#expect()` not `XCTAssert()`

### Test Structure

1. **Test files:** Located in `Tests/`, named `*Tests.swift`
2. **Mocks:** Located in `Tests/Mocks/`, provided for all protocols
3. **Test suite:** One `@Suite` per file, named after the component

### Example Test

```swift
import Testing
import Foundation

@Suite("MusicLibrary")
class MusicLibraryTests {
    @Test("fetches songs successfully")
    func testFetchSongs() async throws {
        let library = MusicLibrary(service: .mock)
        let songs = try await library.songs()
        #expect(!songs.isEmpty)
    }

    @Test("handles authorization denied")
    func testAuthorizationDenied() async throws {
        let library = MusicLibrary(
            authorizationManager: .mock(status: .denied)
        )
        let songs = try await library.songs()
        #expect(songs.isEmpty)
    }
}
```

### Coverage Expectations

- New features should include tests
- Bug fixes should include regression tests
- Aim for meaningful coverage, not just percentage targets

## Documentation Standards

### DocC Comments

All public APIs must have documentation:

```swift
/// Fetches all songs from the music library.
///
/// This method retrieves all available songs, sorted by your preference.
/// It respects the user's media library authorization status.
///
/// - Parameters:
///   - sortedBy: The key path to sort songs by (default: title)
///   - order: Ascending or descending (default: ascending)
/// - Returns: An array of songs, or empty if authorization denied
/// - Throws: `AuthorizationError` if authorization status is undetermined
///
/// ## Overview
///
/// The method automatically handles authorization checks and will return
/// an empty array if the user hasn't granted access to the media library.
///
/// ## Example
/// ```swift
/// let library = MusicLibrary()
/// let songs = try await library.songs(sortedBy: \MPMediaItem.playCount, order: .reverse)
/// print("Found \(songs.count) songs")
/// ```
public func songs(
    sortedBy: KeyPath<MPMediaItem, Comparable> = \MPMediaItem.title,
    order: SortOrder = .forward
) async throws -> [MPMediaItem]
```

### DocC Structure

Include these sections where relevant:
- **Summary:** One-line description
- **Overview:** Detailed explanation
- **Architecture:** How component fits together
- **Usage:** Common use cases
- **Example:** Working code example
- **Topics:** Related items for DocC catalog

## Reporting Issues

### Bug Reports

Include:
- Clear description of the issue
- Steps to reproduce
- Expected behavior
- Actual behavior
- iOS version and Xcode version

### Feature Requests

Include:
- Use case and motivation
- Proposed solution (if you have one)
- Alternatives you've considered

### Security Vulnerabilities

**Do not** open a public issue. Please contact the maintainers privately.

## Pull Request Checklist

Before submitting a PR, ensure:

- [ ] Tests are added or updated for new/changed code
- [ ] All tests pass: `swift test`
- [ ] Documentation is added/updated for public APIs
- [ ] Code follows project style conventions
- [ ] Commit messages follow conventions
- [ ] PR description includes `Closes #{issue-number}`
- [ ] No new external dependencies added
- [ ] Code is free of debug logging and temporary changes
- [ ] CHANGELOG.md updated with your changes

## Updating the CHANGELOG

We maintain a [CHANGELOG.md](CHANGELOG.md) file following [Keep a Changelog](https://keepachangelog.com/) format.

When submitting a PR with changes:

1. Add an entry under the `[Unreleased]` section
2. Use appropriate category: Added, Changed, Fixed, Removed
3. Keep entries concise and user-focused

Example:
```markdown
## [Unreleased]

### Added
- New feature description
- Another improvement

### Fixed
- Bug fix description
```

The maintainers will move entries to a version number when a release is created.

## Questions?

Feel free to:
- Open a discussion on GitHub
- Review existing issues for similar questions
- Check the documentation at: `swift package generate-documentation`

---

Thank you for contributing to MediaBridge! 🎵
