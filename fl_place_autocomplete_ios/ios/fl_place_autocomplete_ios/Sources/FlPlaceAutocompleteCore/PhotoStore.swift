import Foundation

/// Keeps native photo handles addressable by an opaque id (Dart only sees the
/// id). Least-recently-used entries are evicted beyond `capacity`.
public final class PhotoStore<T> {
    private let capacity: Int
    private var values: [String: T] = [:]
    private var order: [String] = [] // least recently used first
    private let lock = NSLock()

    public init(capacity: Int = 200) { self.capacity = max(1, capacity) }

    /// Stores `value` and returns its new id.
    public func put(_ value: T) -> String {
        lock.lock(); defer { lock.unlock() }
        let id = UUID().uuidString
        values[id] = value
        order.append(id)
        while order.count > capacity {
            values[order.removeFirst()] = nil
        }
        return id
    }

    /// Returns the value for `id` (marking it recently used), or `nil`.
    public func get(_ id: String) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let value = values[id] else { return nil }
        if let index = order.firstIndex(of: id) {
            order.remove(at: index)
            order.append(id)
        }
        return value
    }
}
