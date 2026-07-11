import WinSDK
import CWin32
import SwiftOpenUI

// MARK: - Win32 intrinsic sizing
//
// Apple platforms give every view an `intrinsicContentSize` and SwiftUI a
// `Layout.sizeThatFits`, so containers can measure a child before placing
// it. Win32 has no OS-level intrinsic sizing, so the backend's default is
// the "render the HWND, then GetWindowRect it" convention.
//
// `WinMeasurable` formalizes the up-front alternative: a custom control
// declares its intrinsic content size directly, so a parent can size it
// without a throwaway render. It's opt-in — views that don't conform keep
// using the render-then-measure path via `winMeasure` returning nil.

/// Device-pixel size — the Win32 backend's native currency. (The shared
/// cross-platform layout core uses the Double-based `ViewSize`; bridge with
/// `viewSize` when feeding `computeFrameLayout` / `computeVStackLayout`.)
public struct WinSize: Equatable {
    public var width: Int32
    public var height: Int32
    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }
    public static let zero = WinSize(width: 0, height: 0)
    public var viewSize: ViewSize { ViewSize(width: Double(width), height: Double(height)) }
}

/// Per-axis constraint for a measurement. A `nil` axis means "size to
/// content" on that axis (the common intrinsic case).
public struct WinSizeProposal: Equatable {
    public var width: Int32?
    public var height: Int32?
    public init(width: Int32? = nil, height: Int32? = nil) {
        self.width = width
        self.height = height
    }
    public static let unspecified = WinSizeProposal()
}

public enum WinAxis { case horizontal, vertical }

/// A view (or its Win32 renderer) that can report its intrinsic content
/// size *without being rendered first* — the Win32 analog of Apple's
/// `intrinsicContentSize` / SwiftUI's `Layout.sizeThatFits`.
///
/// `hwnd` is any live window in the target hierarchy; it's used only for
/// DPI/font-correct text metrics (`measureText`), not mutated.
public protocol WinMeasurable {
    func winIntrinsicSize(_ proposal: WinSizeProposal, measuringAgainst hwnd: HWND) -> WinSize
}

public extension WinMeasurable {
    /// Convenience: measure with no constraints (pure intrinsic size).
    func winIntrinsicSize(measuringAgainst hwnd: HWND) -> WinSize {
        winIntrinsicSize(.unspecified, measuringAgainst: hwnd)
    }
}

/// Intrinsic size of a view when it conforms to `WinMeasurable`, else
/// `nil` so the caller falls back to the render-then-`GetWindowRect`
/// convention. This is the single entry point a container should use to
/// try measuring a child cheaply.
func winMeasure<V: View>(_ view: V, proposal: WinSizeProposal = .unspecified,
                         against hwnd: HWND) -> WinSize? {
    (view as? WinMeasurable)?.winIntrinsicSize(proposal, measuringAgainst: hwnd)
}

// MARK: - Composition helpers
//
// Building blocks for a `winIntrinsicSize` implementation: measure the
// parts (text, icon, …) and compose them the way the control lays them out.

/// Natural size of a text run in the default UI font, DPI-correct for
/// `hwnd`.
func winTextSize(_ text: String, against hwnd: HWND) -> WinSize {
    let m = measureText(text, hwnd: hwnd)
    return WinSize(width: m.width, height: m.height)
}

/// Natural size of `count` fixed-size square glyphs of the given side.
func winIconSize(side: Int32) -> WinSize {
    WinSize(width: side, height: side)
}

/// Compose child sizes along an axis — the natural size of an HStack/VStack
/// of these children: sum along `axis` (plus inter-child `spacing`), max on
/// the cross axis. Optional `padding` insets the whole result on both sides
/// of each axis.
func winComposeSize(_ children: [WinSize], axis: WinAxis,
                    spacing: Int32 = 0, padding: Int32 = 0) -> WinSize {
    guard !children.isEmpty else {
        return WinSize(width: padding * 2, height: padding * 2)
    }
    let gaps = spacing * Int32(children.count - 1)
    let sizeAlong = children.reduce(0) { $0 + (axis == .horizontal ? $1.width : $1.height) } + gaps
    let sizeCross = children.map { axis == .horizontal ? $0.height : $0.width }.max() ?? 0
    switch axis {
    case .horizontal:
        return WinSize(width: sizeAlong + padding * 2, height: sizeCross + padding * 2)
    case .vertical:
        return WinSize(width: sizeCross + padding * 2, height: sizeAlong + padding * 2)
    }
}
