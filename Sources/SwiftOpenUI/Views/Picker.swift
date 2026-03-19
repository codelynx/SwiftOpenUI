/// A control for selecting from a set of options.
///
/// ```swift
/// Picker("Color", selection: $selectedColor) {
///     Text("Red").tag("red")
///     Text("Blue").tag("blue")
/// }
/// ```
public struct Picker<SelectionValue: Hashable, Content: View>: View {
    public typealias Body = Never

    public let label: String
    public let selection: Binding<SelectionValue>
    public let content: Content

    public init(_ label: String, selection: Binding<SelectionValue>,
                @ViewBuilder content: () -> Content) {
        self.label = label
        self.selection = selection
        self.content = content()
    }

    public var body: Never { fatalError("Picker is a primitive view") }
}

// MARK: - Tag support

/// A view with a tag value for identification in Picker.
public struct TaggedView<Content: View, V: Hashable>: View {
    public typealias Body = Never

    public let content: Content
    public let tagValue: V

    public var body: Never { fatalError("TaggedView is a primitive view") }
}

extension View {
    /// Associate a tag value with this view for use in Picker selection.
    public func tag<V: Hashable>(_ value: V) -> TaggedView<Self, V> {
        TaggedView(content: self, tagValue: value)
    }
}
