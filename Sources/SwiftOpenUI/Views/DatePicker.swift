#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

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
        var t = time(nil)
        var tm = tm()
        #if os(Windows)
        _ = localtime_s(&tm, &t)
        #else
        localtime_r(&t, &tm)
        #endif
        self.year = Int(tm.tm_year) + 1900
        self.month = Int(tm.tm_mon) + 1
        self.day = Int(tm.tm_mday)
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
