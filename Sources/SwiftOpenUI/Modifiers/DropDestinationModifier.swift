import Foundation

/// A view that accepts dropped file URLs from the system.
///
/// When the user drags files from the OS file manager and drops them
/// onto this view's content area, the `action` closure receives an
/// array of file URLs and a drop location. Returns `true` if the
/// drop was accepted, `false` otherwise.
///
/// The `isTargeted` callback fires with `true` when a drag enters
/// the view's bounds and `false` when it leaves. This enables
/// visual hover feedback (e.g., highlighted border). Note: Win32
/// does not support `isTargeted` in M3 (degraded behavior).
///
/// Only file/folder URL drops are supported. For arbitrary data
/// types, a full `Transferable` implementation would be needed
/// (not in scope for M3).
public struct DropDestinationView<Content: View>: View, PrimitiveView {
	public typealias Body = Never
	public let content: Content
	public let action: ([URL], CGPoint) -> Bool
	public let isTargeted: ((Bool) -> Void)?

	public var body: Never { fatalError() }
}

extension View {
	/// Makes this view a drop destination for file URLs.
	///
	/// ```swift
	/// MyView()
	///     .dropDestination(for: URL.self) { urls, location in
	///         handleDrop(urls: urls)
	///     } isTargeted: { hovering in
	///         isHovering = hovering
	///     }
	/// ```
	///
	/// - Parameters:
	///   - type: The type of items accepted (currently only `URL.self`).
	///   - action: Closure receiving dropped URLs and drop location.
	///     Return `true` to accept the drop, `false` to reject.
	///   - isTargeted: Optional closure called with `true` when a drag
	///     enters the view and `false` when it leaves. Win32: no-op.
	public func dropDestination(
		for type: URL.Type,
		action: @escaping ([URL], CGPoint) -> Bool,
		isTargeted: ((Bool) -> Void)? = nil
	) -> DropDestinationView<Self> {
		DropDestinationView(content: self, action: action, isTargeted: isTargeted)
	}
}
