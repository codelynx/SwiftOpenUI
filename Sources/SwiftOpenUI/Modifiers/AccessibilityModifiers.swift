/// Accessibility modifiers accepted for SwiftUI API parity.
///
/// `.accessibilityIdentifier(_:)` names a view for UI-test automation.
/// It has no visual effect. On GTK4/Win32 it currently passes through
/// (parity matrix note); a future pass can map it to the platform
/// automation id (GtkAccessible name / UI Automation AutomationId).
extension View {
    public func accessibilityIdentifier(_ identifier: String) -> Self { self }
}
