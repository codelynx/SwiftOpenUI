/// A view that hides its controls' inline labels. Matches SwiftUI's
/// `.labelsHidden()` for selection controls (Picker, Toggle, etc.)
/// where the surrounding layout already conveys what the control is.
///
/// Implemented via an environment flag — the backend renderers for
/// label-carrying controls (currently `Picker`) read
/// `EnvironmentValues.labelsHidden` during their own render and omit
/// the label prefix when it's set.
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

// MARK: - Environment plumbing

/// Environment flag set by `LabelsHiddenView` for its content subtree.
/// Backends consulting `labelsHidden` on the current environment omit
/// inline labels from label-bearing controls (e.g. Picker).
struct LabelsHiddenKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    public var labelsHidden: Bool {
        get { self[LabelsHiddenKey.self] }
        set { self[LabelsHiddenKey.self] = newValue }
    }
}
