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

    /// Binding-based initializer.
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
