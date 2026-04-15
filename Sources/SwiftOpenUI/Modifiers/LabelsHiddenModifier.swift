/// A view that hides its controls' inline labels. Matches SwiftUI's
/// `.labelsHidden()` for selection controls (Picker, Toggle, etc.)
/// where the surrounding layout already conveys what the control is.
///
/// For GTK4 V1 this is effectively a pass-through: the `.segmented`
/// style already renders without the `label` prefix, and the
/// dropdown style doesn't render the label inline either (the label
/// is used for accessibility only). The modifier still exists so
/// source-shared views can compile on both macOS and Linux.
public struct LabelsHiddenView<Content: View>: View {
    public typealias Body = Never

    public let content: Content

    public var body: Never { fatalError("LabelsHiddenView is a primitive view") }
}

extension View {
    /// Hide the inline labels of selection controls within this view.
    public func labelsHidden() -> LabelsHiddenView<Self> {
        LabelsHiddenView(content: self)
    }
}
