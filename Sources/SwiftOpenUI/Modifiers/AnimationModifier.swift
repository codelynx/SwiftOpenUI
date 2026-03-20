/// Describes an animation's timing and curve.
public struct Animation: Equatable {
    public enum Curve: Equatable {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case spring
    }

    public let curve: Curve
    public let duration: Double

    public init(curve: Curve = .easeInOut, duration: Double = 0.35) {
        self.curve = curve
        self.duration = duration
    }

    public static let `default` = Animation()
    public static let linear = Animation(curve: .linear, duration: 0.35)
    public static let easeIn = Animation(curve: .easeIn, duration: 0.35)
    public static let easeOut = Animation(curve: .easeOut, duration: 0.35)
    public static let easeInOut = Animation(curve: .easeInOut, duration: 0.35)
    public static let spring = Animation(curve: .spring, duration: 0.5)

    public static func linear(duration: Double) -> Animation { Animation(curve: .linear, duration: duration) }
    public static func easeIn(duration: Double) -> Animation { Animation(curve: .easeIn, duration: duration) }
    public static func easeOut(duration: Double) -> Animation { Animation(curve: .easeOut, duration: duration) }
    public static func easeInOut(duration: Double) -> Animation { Animation(curve: .easeInOut, duration: duration) }
}

/// A view with an opacity applied.
public struct OpacityView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let opacity: Double

    public var body: Never { fatalError("OpacityView is a primitive view") }
}

/// A view with a positional offset applied.
public struct OffsetView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let x: Double
    public let y: Double

    public var body: Never { fatalError("OffsetView is a primitive view") }
}

/// A view with a scale transform applied.
public struct ScaleEffectView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let scaleX: Double
    public let scaleY: Double

    public var body: Never { fatalError("ScaleEffectView is a primitive view") }
}

/// A view with a CSS transition animation applied.
public struct AnimatedView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let animation: Animation?

    public var body: Never { fatalError("AnimatedView is a primitive view") }
}

extension View {
    /// Set the opacity of this view.
    public func opacity(_ opacity: Double) -> OpacityView<Self> {
        OpacityView(content: self, opacity: opacity)
    }

    /// Offset this view by the specified amounts.
    public func offset(x: Double = 0, y: Double = 0) -> OffsetView<Self> {
        OffsetView(content: self, x: x, y: y)
    }

    /// Apply a scale transform to this view.
    public func scaleEffect(_ scale: Double) -> ScaleEffectView<Self> {
        ScaleEffectView(content: self, scaleX: scale, scaleY: scale)
    }

    /// Apply a scale transform with independent x and y factors.
    public func scaleEffect(x: Double = 1, y: Double = 1) -> ScaleEffectView<Self> {
        ScaleEffectView(content: self, scaleX: x, scaleY: y)
    }

    /// Associate an animation with this view. Changes to the view's properties
    /// will be animated with the given timing curve.
    public func animation(_ animation: Animation?, value: some Equatable) -> AnimatedView<Self> {
        AnimatedView(content: self, animation: animation)
    }

    /// Convenience: animate all changes with the given animation.
    public func animation(_ animation: Animation?) -> AnimatedView<Self> {
        AnimatedView(content: self, animation: animation)
    }
}

// MARK: - withAnimation

#if canImport(Glibc) || canImport(Darwin)
import Foundation

private let _animKey: pthread_key_t = {
    var key = pthread_key_t()
    pthread_key_create(&key, nil)
    return key
}()

/// Set the current animation context for a state change.
public func setCurrentAnimation(_ animation: Animation?) {
    if let animation = animation {
        let box = Unmanaged.passRetained(AnimationBox(animation)).toOpaque()
        if let prev = pthread_getspecific(_animKey) {
            Unmanaged<AnimationBox>.fromOpaque(prev).release()
        }
        pthread_setspecific(_animKey, box)
    } else {
        if let prev = pthread_getspecific(_animKey) {
            Unmanaged<AnimationBox>.fromOpaque(prev).release()
        }
        pthread_setspecific(_animKey, nil)
    }
}

/// Get the current animation (if a withAnimation block is active).
public func getCurrentAnimation() -> Animation? {
    guard let ptr = pthread_getspecific(_animKey) else { return nil }
    return Unmanaged<AnimationBox>.fromOpaque(ptr).takeUnretainedValue().animation
}

#elseif canImport(WinSDK)
import WinSDK

private let _animTls: DWORD = TlsAlloc()

public func setCurrentAnimation(_ animation: Animation?) {
    if let animation = animation {
        let box = Unmanaged.passRetained(AnimationBox(animation)).toOpaque()
        if let prev = TlsGetValue(_animTls) {
            Unmanaged<AnimationBox>.fromOpaque(prev).release()
        }
        TlsSetValue(_animTls, box)
    } else {
        if let prev = TlsGetValue(_animTls) {
            Unmanaged<AnimationBox>.fromOpaque(prev).release()
        }
        TlsSetValue(_animTls, nil)
    }
}

public func getCurrentAnimation() -> Animation? {
    guard let ptr = TlsGetValue(_animTls) else { return nil }
    return Unmanaged<AnimationBox>.fromOpaque(ptr).takeUnretainedValue().animation
}
#else
private var _currentAnimation: Animation?

public func setCurrentAnimation(_ animation: Animation?) {
    _currentAnimation = animation
}

public func getCurrentAnimation() -> Animation? {
    _currentAnimation
}
#endif

private class AnimationBox {
    let animation: Animation
    init(_ animation: Animation) { self.animation = animation }
}

// MARK: - Pending animation (survives until consumed by rebuild)

#if canImport(Glibc) || canImport(Darwin)
private let _pendingAnimKey: pthread_key_t = {
    var key = pthread_key_t()
    pthread_key_create(&key, nil)
    return key
}()

public func setPendingAnimation(_ animation: Animation?) {
    if let animation = animation {
        let box = Unmanaged.passRetained(AnimationBox(animation)).toOpaque()
        if let prev = pthread_getspecific(_pendingAnimKey) {
            Unmanaged<AnimationBox>.fromOpaque(prev).release()
        }
        pthread_setspecific(_pendingAnimKey, box)
    } else {
        if let prev = pthread_getspecific(_pendingAnimKey) {
            Unmanaged<AnimationBox>.fromOpaque(prev).release()
        }
        pthread_setspecific(_pendingAnimKey, nil)
    }
}

public func getPendingAnimation() -> Animation? {
    guard let ptr = pthread_getspecific(_pendingAnimKey) else { return nil }
    return Unmanaged<AnimationBox>.fromOpaque(ptr).takeUnretainedValue().animation
}

#elseif canImport(WinSDK)

private let _pendingAnimTls: DWORD = TlsAlloc()

public func setPendingAnimation(_ animation: Animation?) {
    if let animation = animation {
        let box = Unmanaged.passRetained(AnimationBox(animation)).toOpaque()
        if let prev = TlsGetValue(_pendingAnimTls) {
            Unmanaged<AnimationBox>.fromOpaque(prev).release()
        }
        TlsSetValue(_pendingAnimTls, box)
    } else {
        if let prev = TlsGetValue(_pendingAnimTls) {
            Unmanaged<AnimationBox>.fromOpaque(prev).release()
        }
        TlsSetValue(_pendingAnimTls, nil)
    }
}

public func getPendingAnimation() -> Animation? {
    guard let ptr = TlsGetValue(_pendingAnimTls) else { return nil }
    return Unmanaged<AnimationBox>.fromOpaque(ptr).takeUnretainedValue().animation
}

#else
private var _pendingAnimation: Animation?

public func setPendingAnimation(_ animation: Animation?) {
    _pendingAnimation = animation
}

public func getPendingAnimation() -> Animation? {
    _pendingAnimation
}
#endif

/// Perform a state change with animation.
///
/// ```swift
/// withAnimation(.easeInOut(duration: 0.3)) {
///     showDetail = true
/// }
/// ```
public func withAnimation(_ animation: Animation = .default, _ body: () -> Void) {
    let previous = getCurrentAnimation()
    setCurrentAnimation(animation)
    setPendingAnimation(animation)
    body()
    setCurrentAnimation(previous)
    // Note: pendingAnimation is NOT cleared here — it persists until
    // the next rebuild consumes it, because the rebuild is deferred
    // via PostMessage/g_idle_add and runs after withAnimation returns.
}

/// Consume the pending animation (called by backends during rebuild).
/// Returns the animation if one was set by a recent withAnimation block.
public func consumePendingAnimation() -> Animation? {
    let anim = getPendingAnimation()
    setPendingAnimation(nil)
    return anim
}
