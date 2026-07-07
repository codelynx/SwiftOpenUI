/// SwiftUI's `.listStyle(_:)` — accepted for API parity. GTK4's List already
/// renders in a plain style; style variants are not yet differentiated on any
/// backend (parity matrix note).
public protocol ListStyle: Sendable {}
public struct PlainListStyle: ListStyle { public init() {} }
public struct AutomaticListStyle: ListStyle { public init() {} }
public struct InsetListStyle: ListStyle { public init() {} }

extension ListStyle where Self == PlainListStyle {
    public static var plain: PlainListStyle { PlainListStyle() }
}
extension ListStyle where Self == AutomaticListStyle {
    public static var automatic: AutomaticListStyle { AutomaticListStyle() }
}
extension ListStyle where Self == InsetListStyle {
    public static var inset: InsetListStyle { InsetListStyle() }
}

extension View {
    public func listStyle(_ style: some ListStyle) -> Self { self }
}
