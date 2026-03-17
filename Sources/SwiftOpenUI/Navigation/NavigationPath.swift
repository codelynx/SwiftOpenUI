/// A type-erased stack of navigation destinations, matching SwiftUI's NavigationPath API.
///
/// ```swift
/// @State private var path = NavigationPath()
///
/// NavigationStack(path: $path) {
///     Button("Go to Detail") { path.append("detail-1") }
/// }
/// .navigationDestination(for: String.self) { value in
///     Text("Detail: \(value)")
/// }
/// ```
public struct NavigationPath {
    /// Type-erased elements in the path.
    public var elements: [AnyHashable] = []

    public init() {}

    /// The number of elements in the path.
    public var count: Int { elements.count }

    /// Whether the path is empty.
    public var isEmpty: Bool { elements.isEmpty }

    /// Append a hashable value to the path (pushes a new view).
    public mutating func append<V: Hashable>(_ value: V) {
        elements.append(AnyHashable(value))
    }

    /// Remove the last element (pops the top view).
    public mutating func removeLast(_ k: Int = 1) {
        let removeCount = min(k, elements.count)
        elements.removeLast(removeCount)
    }
}
