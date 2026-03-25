/// Safe-area regions that a view may respect or ignore.
public struct SafeAreaRegions: OptionSet, Equatable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let container = SafeAreaRegions(rawValue: 1 << 0)
    public static let keyboard = SafeAreaRegions(rawValue: 1 << 1)
    public static let all: SafeAreaRegions = [.container, .keyboard]
}

/// A vertical edge used by safe-area APIs.
public enum VerticalEdge: Equatable {
    case top
    case bottom
}

/// A horizontal edge used by safe-area APIs.
public enum HorizontalEdge: Equatable {
    case leading
    case trailing
}

/// A normalized edge representation for stored safe-area inset modifiers.
public enum SafeAreaInsetEdge: Equatable {
    case top
    case bottom
    case leading
    case trailing
}

/// Cross-axis alignment stored by safe-area inset modifiers.
public enum SafeAreaInsetAlignment: Equatable {
    case horizontal(HorizontalAlignment)
    case vertical(VerticalAlignment)
}
