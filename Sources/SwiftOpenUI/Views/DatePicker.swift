import Foundation

/// A simple date value type for DatePicker (no Foundation dependency).
public struct DateComponents: Equatable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Creates DateComponents for today's date.
    public init() {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        self.year = components.year ?? 1970
        self.month = components.month ?? 1
        self.day = components.day ?? 1
    }
}

/// A date picker backed by a native calendar widget.
public struct DatePicker: View {
    public typealias Body = Never

    public let title: String
    public let selection: Binding<DateComponents>?
    public let onChange: ((DateComponents) -> Void)?

    /// Creates a DatePicker with a binding.
    public init(_ title: String = "", selection: Binding<DateComponents>) {
        self.title = title
        self.selection = selection
        self.onChange = nil
    }

    /// Creates a DatePicker with a callback.
    public init(_ title: String = "", onChange: ((DateComponents) -> Void)? = nil) {
        self.title = title
        self.selection = nil
        self.onChange = onChange
    }

    public var body: Never { fatalError("DatePicker is a primitive view") }
}
