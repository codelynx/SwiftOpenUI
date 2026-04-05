// MARK: - Text Alignment

/// Alignment for multi-line text content.
public enum TextAlignment: Equatable {
    case leading
    case center
    case trailing
}

// MARK: - Truncation Mode

/// How text is truncated when it doesn't fit.
public enum TruncationMode: Equatable {
    case head
    case tail
    case middle
}

// MARK: - Line Limit

/// Wraps content with a line limit constraint.
public struct LineLimitView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let lineLimit: Int?

    public var body: Never { fatalError() }
}

// MARK: - Truncation Mode

/// Wraps content with a truncation mode.
public struct TruncationModeView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let mode: TruncationMode

    public var body: Never { fatalError() }
}

// MARK: - Line Spacing

/// Wraps content with additional line spacing.
public struct LineSpacingView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let spacing: Double

    public var body: Never { fatalError() }
}

// MARK: - Multiline Text Alignment

/// Wraps content with a text alignment for multi-line text.
public struct MultilineTextAlignmentView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let alignment: TextAlignment

    public var body: Never { fatalError() }
}

// MARK: - View Extensions

extension View {
    /// Limits the number of lines text can occupy.
    /// Pass `nil` for unlimited lines.
    public func lineLimit(_ number: Int?) -> LineLimitView<Self> {
        LineLimitView(content: self, lineLimit: number)
    }

    /// Sets the truncation mode for text that doesn't fit.
    public func truncationMode(_ mode: TruncationMode) -> TruncationModeView<Self> {
        TruncationModeView(content: self, mode: mode)
    }

    /// Sets the amount of space between lines of text.
    public func lineSpacing(_ lineSpacing: Double) -> LineSpacingView<Self> {
        LineSpacingView(content: self, spacing: lineSpacing)
    }

    /// Sets the alignment of multi-line text.
    public func multilineTextAlignment(_ alignment: TextAlignment) -> MultilineTextAlignmentView<Self> {
        MultilineTextAlignmentView(content: self, alignment: alignment)
    }
}
