import Foundation

// MARK: - Content Mode

/// How content fills its container when aspect ratio is constrained.
public enum ContentMode: Equatable {
    /// Scales to fit within the container, preserving aspect ratio.
    /// May leave empty space.
    case fit
    /// Scales to fill the container, preserving aspect ratio.
    /// May clip content.
    case fill
}

// MARK: - Aspect Ratio

/// Constrains the view to a specific aspect ratio.
public struct AspectRatioView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let ratio: Double?
    public let contentMode: ContentMode

    public var body: Never { fatalError() }
}

extension View {
    /// Constrains this view to the given aspect ratio.
    public func aspectRatio(_ ratio: CGFloat? = nil, contentMode: ContentMode) -> AspectRatioView<Self> {
        AspectRatioView(content: self, ratio: ratio.map { Double($0) }, contentMode: contentMode)
    }

    /// Constrains this view to the given width/height ratio.
    public func aspectRatio(_ ratio: CGSize, contentMode: ContentMode) -> AspectRatioView<Self> {
        let r = ratio.height > 0 ? ratio.width / ratio.height : 1
        return AspectRatioView(content: self, ratio: Double(r), contentMode: contentMode)
    }

    /// Scales this view to fit within its parent, preserving aspect ratio.
    public func scaledToFit() -> AspectRatioView<Self> {
        AspectRatioView(content: self, ratio: nil, contentMode: .fit)
    }

    /// Scales this view to fill its parent, preserving aspect ratio.
    public func scaledToFill() -> AspectRatioView<Self> {
        AspectRatioView(content: self, ratio: nil, contentMode: .fill)
    }
}
