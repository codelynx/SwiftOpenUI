import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI
import Foundation

// MARK: - D2D surface rendering
//
// Renders a fully-D2D-renderable view subtree onto a single HWND
// with a Direct2D render target. Supports opacity and scale transforms.
//
// Only works for views that can be measured and drawn without native
// HWND controls: Text, Color, Divider, and simple modifiers wrapping them.

/// Check if a view can be rendered entirely via D2D (no native HWND controls needed).
func isD2DRenderable<V: View>(_ view: V) -> Bool {
    if view is Text { return true }
    if view is Color { return true }
    if view is Divider { return true }
    if view is Spacer { return false } // layout-only, not drawable
    if view is EmptyView { return true }

    // Modifiers wrapping D2D-renderable content
    if let v = view as? any _D2DContentAccess {
        return v._isContentD2DRenderable
    }

    return false
}

/// Internal protocol for checking if a modifier's content is D2D-renderable.
/// Avoids exposing generic content types.
protocol _D2DContentAccess {
    var _isContentD2DRenderable: Bool { get }
}

extension ForegroundColorView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension FontModifiedView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension PaddedView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension ScaleEffectView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension OpacityView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension RotationView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

/// Measure a D2D-renderable view's size.
func d2dMeasure<V: View>(_ view: V) -> (width: Float, height: Float) {
    if let text = view as? Text {
        guard let fmt = D2DRenderer.shared.textFormat() else { return (0, 0) }
        let (w, h) = D2DRenderer.shared.measureText(text.content, format: fmt)
        return (w + 4, h + 2)
    }
    if view is Color {
        return (20, 20) // natural size, will expand in container
    }
    if view is Divider {
        return (100, 2)
    }
    if view is EmptyView {
        return (0, 0)
    }
    if let fg = view as? ForegroundColorView<Text> {
        return d2dMeasure(fg.content)
    }
    if let font = view as? FontModifiedView<Text> {
        let (fontSize, bold, italic) = fontParametersForD2D(font.font)
        guard let fmt = D2DRenderer.shared.textFormat(fontSize: fontSize, bold: bold, italic: italic) else {
            return d2dMeasure(font.content)
        }
        let (w, h) = D2DRenderer.shared.measureText(font.content.content, format: fmt)
        return (w + 4, h + 2)
    }
    if let padded = view as? PaddedView<Text> {
        let inner = d2dMeasure(padded.content)
        return (inner.width + Float(padded.leading + padded.trailing),
                inner.height + Float(padded.top + padded.bottom))
    }
    // Walk through wrapper modifiers that don't change measurement
    if let v = view as? any _D2DMeasurable {
        return v._d2dMeasureContent
    }
    return (0, 0)
}

/// Internal protocol for measuring through wrapper modifiers.
protocol _D2DMeasurable {
    var _d2dMeasureContent: (width: Float, height: Float) { get }
}

extension ScaleEffectView: _D2DMeasurable {
    var _d2dMeasureContent: (width: Float, height: Float) {
        let inner = d2dMeasure(content)
        return (inner.width * Float(scaleX), inner.height * Float(scaleY))
    }
}

extension OpacityView: _D2DMeasurable {
    var _d2dMeasureContent: (width: Float, height: Float) {
        d2dMeasure(content)
    }
}

extension RotationView: _D2DMeasurable {
    var _d2dMeasureContent: (width: Float, height: Float) {
        let inner = d2dMeasure(content)
        // Compute rotated bounding box
        let rad = Float(angle) * .pi / 180.0
        let cosA = abs(cos(rad))
        let sinA = abs(sin(rad))
        let w = inner.width * cosA + inner.height * sinA
        let h = inner.width * sinA + inner.height * cosA
        return (w, h)
    }
}

/// Draw a D2D-renderable view onto a render target.
func d2dDraw<V: View>(_ view: V, target: D2DRenderTarget, brush: D2DBrush,
                       x: Float, y: Float, width: Float, height: Float) {
    if let text = view as? Text {
        guard let fmt = D2DRenderer.shared.textFormat() else { return }
        d2d1_SolidColorBrush_SetColor(brush, 0, 0, 0, 1) // black text
        D2DRenderer.shared.drawText(text.content, target: target, format: fmt,
                                     brush: brush, x: x, y: y, width: width, height: height)
        return
    }
    if let color = view as? Color {
        d2d1_SolidColorBrush_SetColor(brush, Float(color.red), Float(color.green),
                                       Float(color.blue), Float(color.alpha))
        d2d1_RenderTarget_FillRectangle(target, brush, x, y, width, height)
        return
    }
    if view is Divider {
        d2d1_SolidColorBrush_SetColor(brush, 210.0/255, 210.0/255, 215.0/255, 1)
        let lineY = y + height / 2
        d2d1_RenderTarget_FillRectangle(target, brush, x, lineY, width, 1)
        return
    }
    if let fg = view as? ForegroundColorView<Text> {
        d2d1_SolidColorBrush_SetColor(brush, Float(fg.color.red), Float(fg.color.green),
                                       Float(fg.color.blue), Float(fg.color.alpha))
        guard let fmt = D2DRenderer.shared.textFormat() else { return }
        D2DRenderer.shared.drawText(fg.content.content, target: target, format: fmt,
                                     brush: brush, x: x, y: y, width: width, height: height)
        return
    }
    if let font = view as? FontModifiedView<Text> {
        let (fontSize, bold, italic) = fontParametersForD2D(font.font)
        guard let fmt = D2DRenderer.shared.textFormat(fontSize: fontSize, bold: bold, italic: italic) else { return }
        d2d1_SolidColorBrush_SetColor(brush, 0, 0, 0, 1)
        D2DRenderer.shared.drawText(font.content.content, target: target, format: fmt,
                                     brush: brush, x: x, y: y, width: width, height: height)
        return
    }
    if let padded = view as? PaddedView<Text> {
        d2dDraw(padded.content, target: target, brush: brush,
                x: x + Float(padded.leading), y: y + Float(padded.top),
                width: width - Float(padded.leading + padded.trailing),
                height: height - Float(padded.top + padded.bottom))
        return
    }
    // ScaleEffectView: draw content with scaled font size for text
    if let v = view as? any _D2DDrawable {
        v._d2dDrawContent(target: target, brush: brush, x: x, y: y, width: width, height: height)
        return
    }
}

/// Internal protocol for drawing through wrapper modifiers.
protocol _D2DDrawable {
    func _d2dDrawContent(target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float)
}

extension ScaleEffectView: _D2DDrawable {
    func _d2dDrawContent(target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float) {
        // For text content, approximate scale via font size
        if let text = content as? Text {
            let scale = max(scaleX, scaleY)
            let (baseFontSize, bold, italic) = fontParametersForD2D(.body)
            let scaledSize = baseFontSize * Float(scale)
            guard let fmt = D2DRenderer.shared.textFormat(fontSize: scaledSize, bold: bold, italic: italic) else { return }
            D2DRenderer.shared.drawText(text.content, target: target, format: fmt,
                                         brush: brush, x: x, y: y, width: width, height: height)
        } else {
            // For non-text, just draw at natural size (scale not fully supported)
            d2dDraw(content, target: target, brush: brush, x: x, y: y, width: width, height: height)
        }
    }
}

extension OpacityView: _D2DDrawable {
    func _d2dDrawContent(target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float) {
        // Opacity is handled by the D2DSurfaceState, just draw content
        d2dDraw(content, target: target, brush: brush, x: x, y: y, width: width, height: height)
    }
}

extension RotationView: _D2DDrawable {
    func _d2dDrawContent(target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float) {
        let rad = Float(angle) * .pi / 180.0
        let cosA = cos(rad)
        let sinA = sin(rad)

        // Rotate around center of the drawing area
        let cx = x + width / 2
        let cy = y + height / 2

        // Build rotation matrix around center:
        // Translate(-cx,-cy) * Rotate * Translate(cx,cy)
        let dx = cx - cx * cosA + cy * sinA
        let dy = cy - cx * sinA - cy * cosA
        d2d1_RenderTarget_SetTransform(target, cosA, sinA, -sinA, cosA, dx, dy)

        // Draw the inner content at its natural size, centered
        let inner = d2dMeasure(content)
        let ix = cx - inner.width / 2
        let iy = cy - inner.height / 2
        d2dDraw(content, target: target, brush: brush,
                x: ix, y: iy, width: inner.width, height: inner.height)

        // Reset transform
        d2d1_RenderTarget_SetTransformIdentity(target)
    }
}

/// Extract font parameters for D2D text format.
private func fontParametersForD2D(_ font: Font) -> (fontSize: Float, bold: Bool, italic: Bool) {
    switch font {
    case .largeTitle:  return (28, false, false)
    case .title:       return (24, false, false)
    case .title2:      return (20, true, false)
    case .title3:      return (18, false, false)
    case .headline:    return (14, true, false)
    case .subheadline: return (12, true, false)
    case .body:        return (14, false, false)
    case .callout:     return (12, false, false)
    case .footnote:    return (10, false, false)
    case .caption:     return (12, false, false)
    case .caption2:    return (10, true, false)
    case .custom(let size, let w, _):
        let bold = w == .bold || w == .semibold || w == .heavy || w == .black
        return (Float(size), bold, false)
    }
}

// MARK: - D2D Surface Host HWND

private let d2dAnimTimerID: UINT_PTR = 9500
private let d2dAnimFrameMs: UInt32 = 16  // ~60 fps

/// State for a D2D surface HWND that renders a view with optional transforms.
class D2DSurfaceState {
    let hwnd: HWND
    var renderTarget: D2DRenderTarget?
    var brush: D2DBrush?
    /// (target, brush, width, height, opacity, scale)
    let drawContent: (D2DRenderTarget, D2DBrush, Float, Float, Float, Float) -> Void

    // Animation state
    var currentOpacity: Float
    let targetOpacity: Float
    let startOpacity: Float
    var currentScale: Float
    let targetScale: Float
    let startScale: Float
    var animationProgress: Float = 1.0  // 0→1, 1.0 = done
    var animationDuration: Float = 0
    var animationCurve: Animation.Curve = .easeInOut
    var animationStartTime: UInt32 = 0

    init(hwnd: HWND, opacity: Float, scale: Float = 1.0, animation: Animation?,
         drawContent: @escaping (D2DRenderTarget, D2DBrush, Float, Float, Float, Float) -> Void) {
        self.hwnd = hwnd
        self.targetOpacity = opacity
        self.targetScale = scale
        self.drawContent = drawContent

        if let anim = animation {
            self.startOpacity = opacity < 0.5 ? 1.0 : 0.0
            self.currentOpacity = startOpacity
            self.startScale = scale != 1.0 ? 1.0 : scale
            self.currentScale = startScale
            self.animationDuration = Float(anim.duration)
            self.animationCurve = anim.curve
            self.animationProgress = 0
        } else {
            self.startOpacity = opacity
            self.currentOpacity = opacity
            self.startScale = scale
            self.currentScale = scale
        }
    }

    func startAnimation() {
        guard animationProgress < 1.0 else { return }
        animationStartTime = GetTickCount()
        SetTimer(hwnd, d2dAnimTimerID, d2dAnimFrameMs, nil)
    }

    func tick() {
        guard animationDuration > 0 else { return }
        let elapsed = Float(GetTickCount() - animationStartTime) / 1000.0
        let rawProgress = min(elapsed / animationDuration, 1.0)
        animationProgress = applyEasing(rawProgress, curve: animationCurve)
        currentOpacity = startOpacity + (targetOpacity - startOpacity) * animationProgress
        currentScale = startScale + (targetScale - startScale) * animationProgress

        InvalidateRect(hwnd, nil, false)

        if rawProgress >= 1.0 {
            KillTimer(hwnd, d2dAnimTimerID)
            currentOpacity = targetOpacity
            currentScale = targetScale
        }
    }

    func ensureTarget(width: UInt32, height: UInt32) {
        if renderTarget == nil && width > 0 && height > 0 {
            renderTarget = D2DRenderer.shared.createRenderTarget(for: hwnd, width: width, height: height)
            if let rt = renderTarget {
                brush = D2DRenderer.shared.createBrush(rt, r: 0, g: 0, b: 0)
            }
        }
    }

    func resize(width: UInt32, height: UInt32) {
        if let rt = renderTarget, width > 0, height > 0 {
            D2DRenderer.shared.resize(rt, width: width, height: height)
        }
    }

    func paint() {
        if renderTarget == nil {
            var r = RECT()
            GetClientRect(hwnd, &r)
            ensureTarget(width: UInt32(r.right), height: UInt32(r.bottom))
        }
        guard let rt = renderTarget, let brush = brush else { return }

        var rect = RECT()
        GetClientRect(hwnd, &rect)
        let w = Float(rect.right - rect.left)
        let h = Float(rect.bottom - rect.top)
        guard w > 0, h > 0 else { return }

        d2d1_RenderTarget_BeginDraw(rt)
        // Clear with window background
        let bgColor = GetSysColor(COLOR_WINDOW)
        d2d1_RenderTarget_Clear(rt,
            Float(win32_GetRValue(bgColor)) / 255.0,
            Float(win32_GetGValue(bgColor)) / 255.0,
            Float(win32_GetBValue(bgColor)) / 255.0, 1.0)

        // Draw with current (possibly animated) opacity and scale
        // For scale: adjust the drawing area so content renders larger/smaller
        if currentScale != 1.0 {
            // Center the scaled content in the surface
            let scaledW = w / currentScale
            let scaledH = h / currentScale
            let offsetX = (w - scaledW) / 2
            let offsetY = (h - scaledH) / 2
            // We can't truly scale the render target, but we can use
            // a different font size for text. The drawContent callback
            // handles this via the captured scale value.
            _ = (offsetX, offsetY) // available for future transform use
        }
        drawContent(rt, brush, w, h, currentOpacity, currentScale)

        let hr = d2d1_RenderTarget_EndDraw(rt)
        if hr < 0 { cleanup() }
    }

    func cleanup() {
        if let b = brush { D2DRenderer.shared.releaseBrush(b); brush = nil }
        if let rt = renderTarget { D2DRenderer.shared.releaseRenderTarget(rt); renderTarget = nil }
    }

    deinit { cleanup() }
}

/// Create a D2D surface HWND for rendering a view with opacity and/or scale.
/// If an animation is active (via withAnimation), the surface animates
/// from the previous value to the target over the animation duration.
func createD2DSurface<V: View>(
    view: V, opacity: Float = 1.0, scale: Float = 1.0, context: RenderContext
) -> HWND? {
    // Prefer scoped animation from .animation() wrapper (survives the
    // full subtree), then fall back to deferred withAnimation() token
    // (single-consumer, cleared on first use).
    let animation = getCurrentAnimation() ?? consumePendingAnimation()
    registerD2DSurfaceClassIfNeeded(hInstance: context.hInstance)

    let measured = d2dMeasure(view)
    let w = max(Int32(measured.width * scale), 1)
    let h = max(Int32(measured.height * scale), 1)

    let container = CreateWindowExW(
        0, d2dSurfaceClassName, nil,
        DWORD(WS_CHILD | WS_VISIBLE),
        0, 0, w, h,
        context.parent, nil, context.hInstance, nil
    )

    guard let container = container else { return nil }

    let state = D2DSurfaceState(hwnd: container, opacity: opacity, scale: scale, animation: animation) { rt, brush, width, height, currentOpacity, currentScale in
        d2d1_SolidColorBrush_SetColor(brush, 0, 0, 0, currentOpacity)
        // For text, use scaled font size for smooth scale animation
        if let text = view as? Text {
            let (baseFontSize, bold, italic) = fontParametersForD2D(.body)
            let scaledSize = baseFontSize * currentScale
            if let fmt = D2DRenderer.shared.textFormat(fontSize: scaledSize, bold: bold, italic: italic) {
                D2DRenderer.shared.drawText(text.content, target: rt, format: fmt,
                                             brush: brush, x: 0, y: 0, width: width, height: height)
            }
        } else {
            d2dDraw(view, target: rt, brush: brush, x: 0, y: 0, width: width, height: height)
        }
    }

    let ptr = Unmanaged.passRetained(state).toOpaque()
    SetWindowSubclass(container, d2dSurfaceProc, 80, DWORD_PTR(UInt(bitPattern: ptr)))

    return container
}

// MARK: - Window class

let d2dSurfaceClassName: UnsafePointer<WCHAR> = {
    "SwiftUID2DSurface".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

private var d2dSurfaceClassRegistered = false

func registerD2DSurfaceClassIfNeeded(hInstance: HINSTANCE) {
    guard !d2dSurfaceClassRegistered else { return }
    d2dSurfaceClassRegistered = true

    var wc = WNDCLASSEXW()
    wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
    wc.lpfnWndProc = DefWindowProcW
    wc.hInstance = hInstance
    wc.hbrBackground = nil
    wc.lpszClassName = d2dSurfaceClassName
    RegisterClassExW(&wc)
}

private let d2dSurfaceProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let state = Unmanaged<D2DSurfaceState>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_SIZE):
        var rect = RECT()
        GetClientRect(hwnd, &rect)
        state.ensureTarget(width: UInt32(rect.right), height: UInt32(rect.bottom))
        state.resize(width: UInt32(rect.right), height: UInt32(rect.bottom))
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    case UINT(WM_PAINT):
        state.paint()
        _ = ValidateRect(hwnd, nil)
        // Start animation after first paint if needed
        if state.animationProgress < 1.0 && state.animationStartTime == 0 {
            state.startAnimation()
        }
        return 0
    case UINT(WM_TIMER):
        if UINT_PTR(wParam) == d2dAnimTimerID {
            state.tick()
            return 0
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    case UINT(WM_ERASEBKGND):
        return 1
    case UINT(WM_NCDESTROY):
        KillTimer(hwnd, d2dAnimTimerID)
        Unmanaged<D2DSurfaceState>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, d2dSurfaceProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

// MARK: - Easing functions

/// Apply an easing curve to a linear progress value (0→1).
private func applyEasing(_ t: Float, curve: Animation.Curve) -> Float {
    switch curve {
    case .linear:
        return t
    case .easeIn:
        return t * t
    case .easeOut:
        return 1 - (1 - t) * (1 - t)
    case .easeInOut:
        return t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) / 2
    case .spring:
        // Approximation: overshoot then settle
        let d: Float = 0.8
        return 1 - expf(-6 * t) * cosf(4 * .pi * t) * d + (1 - d) * (1 - expf(-6 * t))
    }
}
