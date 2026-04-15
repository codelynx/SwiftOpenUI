/// Display style for Picker.
public enum PickerStyle {
    case automatic
    case segmented
    case palette
}

/// A dropdown picker or segmented toggle control.
public struct Picker: View {
    public typealias Body = Never

    public let label: String
    public let options: [String]
    public let selected: Int
    public let onChanged: ((Int) -> Void)?
    public let style: PickerStyle

    /// Callback-based initializer.
    public init(_ label: String, selection: Int = 0, options: [String],
                onChanged: ((Int) -> Void)? = nil) {
        self.label = label
        self.options = options
        self.selected = selection
        self.onChanged = onChanged
        self.style = .automatic
    }

    /// Binding-based initializer (Int-indexed).
    public init(_ label: String, selection: Binding<Int>, options: [String]) {
        self.label = label
        self.options = options
        self.selected = selection.wrappedValue
        self.onChanged = { newValue in
            if newValue != selection.wrappedValue {
                selection.wrappedValue = newValue
            }
        }
        self.style = .automatic
    }

    /// SwiftUI-shaped generic initializer.
    ///
    /// Usage:
    /// ```swift
    /// Picker("Action", selection: $selectedAction) {
    ///     ForEach(DiffaAction.allCases, id: \.self) { action in
    ///         Text(action.rawValue.capitalized).tag(action)
    ///     }
    /// }
    /// ```
    ///
    /// At init-time, walks the `@ViewBuilder content` tree, flattens
    /// `MultiChildView` aggregators (TupleView, ForEach, ViewList),
    /// finds `TagView` descendants, and extracts
    /// `(label, tag)` pairs. The label is read from a wrapped `Text`;
    /// non-Text tagged content falls back to `String(describing:)` of
    /// the tag value. The caller's `Binding<Value>` is then wrapped
    /// into the existing Int-indexed backing: reads map the current
    /// value to its index in the tag list, writes map the chosen
    /// index back to the corresponding tag.
    ///
    /// Unlike SwiftUI's fully-generic Picker, this V1 collapses the
    /// options at init time. Consequences:
    ///   - A Picker built from dynamic data (e.g. ForEach over a
    ///     mutable array) re-walks on view-rebuild, which is cheap.
    ///   - `SelectionValue` must be hashable (required anyway by
    ///     `Binding` equality comparisons in practice).
    public init<SelectionValue: Hashable, Content: View>(
        _ label: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        let extracted = walkForTags(content())
        self.label = label
        self.options = extracted.map { $0.label }
        self.style = .automatic

        let tags = extracted.map { $0.tag }
        let currentKey = AnyHashable(selection.wrappedValue)
        self.selected = tags.firstIndex(of: currentKey) ?? 0

        self.onChanged = { newIndex in
            guard tags.indices.contains(newIndex),
                  let newValue = tags[newIndex].base as? SelectionValue
            else { return }
            if newValue != selection.wrappedValue {
                selection.wrappedValue = newValue
            }
        }
    }

    /// Internal initializer with style.
    init(_ label: String, options: [String], selected: Int,
         onChanged: ((Int) -> Void)?, style: PickerStyle) {
        self.label = label
        self.options = options
        self.selected = selected
        self.onChanged = onChanged
        self.style = style
    }

    /// Apply a picker style.
    public func pickerStyle(_ style: PickerStyle) -> Picker {
        Picker(label, options: options, selected: selected,
               onChanged: onChanged, style: style)
    }

    public var body: Never { fatalError("Picker is a primitive view") }
}

// MARK: - Tag extraction walker

/// Walks an arbitrary view tree looking for `TagView` descendants,
/// flattening `MultiChildView` aggregators along the way. Returns the
/// extracted `(label, tag)` pairs in traversal order — matching the
/// order the user wrote them in the `@ViewBuilder` block.
///
/// The label is read from a wrapped `Text` when present (the 99%
/// case for Picker usage); other view types fall back to
/// `String(describing:)` of the tag value so the dropdown still has
/// a human-legible option.
func walkForTags(_ root: any View) -> [(label: String, tag: AnyHashable)] {
    var result: [(label: String, tag: AnyHashable)] = []
    walkForTagsRecursive(root, into: &result)
    return result
}

private func walkForTagsRecursive(
    _ view: any View,
    into result: inout [(label: String, tag: AnyHashable)]
) {
    if let tagged = view as? AnyTagView {
        let label: String
        if let text = tagged.anyTagContent as? Text {
            label = text.content
        } else {
            label = String(describing: tagged.anyTagValue.base)
        }
        result.append((label, tagged.anyTagValue))
        return
    }
    if let multi = view as? MultiChildView {
        for child in multi.children {
            walkForTagsRecursive(child, into: &result)
        }
        return
    }
    // Unhandled view shape — silently skip. The empty-options case
    // already has defensive handling in the renderer.
}
