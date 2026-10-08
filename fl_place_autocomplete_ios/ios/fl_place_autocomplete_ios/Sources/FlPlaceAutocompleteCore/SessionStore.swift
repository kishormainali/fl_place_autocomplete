import Foundation

/// Maps Dart-side session ids to native session tokens.
///
/// A token is created lazily on first use and lives until `remove` is called
/// (on a successful Place Details fetch or when Dart disposes the session).
public final class SessionStore<T> {
    private var tokens: [String: T] = [:]
    private let lock = NSLock()
    private let make: () -> T

    public init(make: @escaping () -> T) { self.make = make }

    /// Returns the token for `id`, creating it on first use.
    public func getOrCreate(_ id: String) -> T {
        lock.lock(); defer { lock.unlock() }
        if let token = tokens[id] { return token }
        let token = make()
        tokens[id] = token
        return token
    }

    /// Like `getOrCreate`, but `nil` when `id` is `nil` (no session).
    public func getOrNil(_ id: String?) -> T? { id.map(getOrCreate) }

    /// Drops the token for `id`; unknown ids are ignored.
    public func remove(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        tokens[id] = nil
    }
}
