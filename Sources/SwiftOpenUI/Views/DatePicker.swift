import Foundation

/// A control for selecting a date.
///
/// ```swift
/// @State var date = Date()
/// DatePicker("Birthday", selection: $date)
/// ```
public struct DatePicker: View {
    public typealias Body = Never

    public let label: String
    public let selection: Binding<Date>

    public init(_ label: String, selection: Binding<Date>) {
        self.label = label
        self.selection = selection
    }

    public var body: Never { fatalError("DatePicker is a primitive view") }
}
