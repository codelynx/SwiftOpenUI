import SwiftOpenUI
import ExamplesShared

// MARK: - Session state (Application-scoped, survives Activity recreation)

/// The global session — holds the ViewHost and root view reference.
/// Owned at module scope (equivalent to Application singleton on Kotlin side).
private var currentSession: AndroidSession?

private struct AndroidSession {
    let host: AndroidViewHost
    let exampleName: String
}

// MARK: - JNI entry points

/// Create a session and return the initial render tree as JSON.
/// Called from Kotlin: `RenderBridge.nativeCreateSession(name)`
///
/// JNI naming: Java_com_example_swiftopenui_RenderBridge_nativeCreateSession
@_cdecl("Java_com_example_swiftopenui_RenderBridge_nativeCreateSession")
public func jniCreateSession(
    env: UnsafeMutableRawPointer?,
    thisObj: UnsafeMutableRawPointer?,
    jName: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer? {
    guard let env = env, let jName = jName else { return nil }

    let name = jniGetString(env: env, jstring: jName)

    // Reuse existing session if it matches — preserves @State across Activity recreation
    if let existing = currentSession, existing.exampleName == name {
        // Re-render current state (e.g. after Activity recreation)
        androidBeginRenderPass()
        let json = existing.host.buildBody()
        existing.host.pendingJSON = nil
        return jniNewString(env: env, string: json)
    }

    // Create a new session
    let host = createSessionForExample(name: name)
    currentSession = AndroidSession(host: host, exampleName: name)

    // Initial render
    androidBeginRenderPass()
    let json = host.buildBody()
    host.pendingJSON = nil  // consumed immediately

    return jniNewString(env: env, string: json)
}

/// Handle a button click event. Invokes the button's action closure,
/// which may mutate @State and trigger a rebuild.
/// Returns new JSON if the tree was rebuilt, or null if no state changed.
///
/// Called from Kotlin: `RenderBridge.nativeOnButtonClick(nodeId)`
@_cdecl("Java_com_example_swiftopenui_RenderBridge_nativeOnButtonClick")
public func jniOnButtonClick(
    env: UnsafeMutableRawPointer?,
    thisObj: UnsafeMutableRawPointer?,
    nodeId: Int64
) -> UnsafeMutableRawPointer? {
    guard let env = env, let session = currentSession else { return nil }

    // Clear any pending rebuild
    session.host.pendingJSON = nil

    // Look up and invoke the button's action closure
    if let action = androidButtonActions[nodeId] {
        action()
    }

    // If @State changed, scheduleRebuild() was called synchronously,
    // which set pendingJSON with the new tree.
    if let json = session.host.pendingJSON {
        session.host.pendingJSON = nil
        return jniNewString(env: env, string: json)
    }

    // No state change — return null (Kotlin does nothing)
    return nil
}

/// Handle a text input change. Updates the TextField's @Binding<String>,
/// which may mutate @State and trigger a rebuild.
/// Returns new JSON if the tree was rebuilt, or null if no state changed.
///
/// Called from Kotlin: `RenderBridge.nativeOnTextInput(nodeId, text)`
///
/// Kotlin sends text changes immediately (not debounced) so the Binding
/// stays in sync. Rebuild coalescing happens on the Swift side.
@_cdecl("Java_com_example_swiftopenui_RenderBridge_nativeOnTextInput")
public func jniOnTextInput(
    env: UnsafeMutableRawPointer?,
    thisObj: UnsafeMutableRawPointer?,
    nodeId: Int64,
    jText: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer? {
    guard let env = env, let jText = jText, let session = currentSession else { return nil }

    let newText = jniGetString(env: env, jstring: jText)

    // Clear any pending rebuild
    session.host.pendingJSON = nil

    // Update the binding — this triggers @State mutation → scheduleRebuild
    if let binding = androidTextBindings[nodeId] {
        binding.wrappedValue = newText
    }

    // If @State changed, return the new tree
    if let json = session.host.pendingJSON {
        session.host.pendingJSON = nil
        return jniNewString(env: env, string: json)
    }

    return nil
}

/// Handle a focus change event from Kotlin.
/// Updates @FocusState via the registered handler.
/// Focus changes use setValue (not setProgrammatic), so they do NOT
/// trigger rebuilds — this avoids destroying the focused widget.
///
/// Called from Kotlin: `RenderBridge.nativeOnFocusChange(nodeId, hasFocus)`
@_cdecl("Java_com_example_swiftopenui_RenderBridge_nativeOnFocusChange")
public func jniOnFocusChange(
    env: UnsafeMutableRawPointer?,
    thisObj: UnsafeMutableRawPointer?,
    nodeId: Int64,
    hasFocus: UInt8 // JNI jboolean is UInt8
) {
    if let handler = androidFocusHandlers[nodeId] {
        handler(hasFocus != 0)
    }
}

/// Legacy one-shot render for backward compatibility.
/// Called from Kotlin: `RenderBridge.nativeRenderApp(name)`
@_cdecl("Java_com_example_swiftopenui_RenderBridge_nativeRenderApp")
public func jniRenderApp(
    env: UnsafeMutableRawPointer?,
    thisObj: UnsafeMutableRawPointer?,
    jName: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer? {
    guard let env = env, let jName = jName else { return nil }

    let name = jniGetString(env: env, jstring: jName)
    androidBeginRenderPass()
    let json: String

    switch name {
    case "HelloWorld":
        json = renderStaticExample {
            Text("Hello, SwiftOpenUI!")
                .padding()
        }
    case "TextStyles":
        json = renderTextStylesExample()
    case "Buttons":
        json = renderButtonsExample()
    case "Layout":
        json = renderLayoutExample()
    default:
        json = renderStaticExample {
            Text("Unknown example: \(name)")
        }
    }

    return jniNewString(env: env, string: json)
}

// MARK: - Session creation for interactive examples

private func createSessionForExample(name: String) -> AndroidViewHost {
    switch name {
    case "StateDemo":
        return createStateDemoSession()
    case "TextFieldDemo":
        return createTextFieldDemoSession()
    default:
        // Non-interactive examples: wrap in a host that just re-renders statically
        return AndroidViewHost {
            renderStaticExample(name: name)
        }
    }
}

/// Create an interactive StateDemo with real @State.
private func createStateDemoSession() -> AndroidViewHost {
    // var is required — installState reflects over mutable @State properties
    var view = StateDemoRootView() // swiftlint:disable:this redundant_var

    let host = AndroidViewHost { [view] in
        let rootNode = androidRenderView(view)
        let wrapper = RenderNode(type: "window")
        wrapper.props["title"] = "SwiftOpenUI"
        wrapper.children = [rootNode]
        return renderNodeToJSON(wrapper)
    }

    // Wire @State to the host so mutations trigger scheduleRebuild
    installState(view, host: host)

    return host
}

// View structs imported from ExamplesShared:
// - StateDemoRootView (CounterSection, TextToggleSection, etc.)
// - BindingChild
// - TextFieldDemoView

// MARK: - TextField demo

/// Create an interactive TextField demo session.
private func createTextFieldDemoSession() -> AndroidViewHost {
    var view = TextFieldDemoView() // swiftlint:disable:this redundant_var

    let host = AndroidViewHost { [view] in
        let rootNode = androidRenderView(view)
        let wrapper = RenderNode(type: "window")
        wrapper.props["title"] = "SwiftOpenUI"
        wrapper.children = [rootNode]
        return renderNodeToJSON(wrapper)
    }

    installState(view, host: host)
    return host
}

// MARK: - Static example renderers (no @State)

private func renderStaticExample(name: String) -> String {
    switch name {
    case "HelloWorld":
        return renderStaticExample {
            Text("Hello, SwiftOpenUI!")
                .padding()
        }
    case "TextStyles":
        return renderTextStylesExample()
    case "Buttons":
        return renderButtonsExample()
    case "Layout":
        return renderLayoutExample()
    default:
        return renderStaticExample {
            Text("Unknown example: \(name)")
        }
    }
}

/// Helper: render a simple view to JSON (no state).
private func renderStaticExample<V: View>(@ViewBuilder content: () -> V) -> String {
    let rootNode = androidRenderView(content())
    let wrapper = RenderNode(type: "window")
    wrapper.props["title"] = "SwiftOpenUI"
    wrapper.children = [rootNode]
    return renderNodeToJSON(wrapper)
}

private func renderTextStylesExample() -> String {
    renderStaticExample {
        VStack(spacing: 4) {
            Text("Large Title").font(.largeTitle)
            Text("Title").font(.title)
            Text("Title 2").font(.title2)
            Text("Title 3").font(.title3)
            Text("Headline").font(.headline)
            Text("Subheadline").font(.subheadline)
            Text("Body").font(.body)
            Text("Callout").font(.callout)
            Text("Footnote").font(.footnote)
            Text("Caption").font(.caption)
        }
    }
}

private func renderButtonsExample() -> String {
    renderStaticExample {
        VStack(spacing: 8) {
            Text("Buttons").font(.largeTitle)
            Button("Tap Me") { }
            Button("Red Button") { }
            Button("Green Button") { }
        }
        .padding()
    }
}

private func renderLayoutExample() -> String {
    renderStaticExample {
        VStack(spacing: 8) {
            Text("Layout").font(.largeTitle)
            HStack(spacing: 16) {
                Text("Left")
                Spacer()
                Text("Right")
            }
            ZStack {
                Color.blue.opacity(0.2)
                Text("Centered on blue")
            }
            .frame(width: 200, height: 100)
        }
        .padding()
    }
}

// MARK: - JNI string helpers

/// Read a Java String from JNI.
func jniGetString(env: UnsafeMutableRawPointer, jstring: UnsafeMutableRawPointer) -> String {
    let envPtr = env.assumingMemoryBound(to: UnsafeMutablePointer<UnsafeMutableRawPointer?>.self)
    let functions = envPtr.pointee

    // GetStringUTFChars is function #169
    let getStringUTFChars = functions.advanced(by: 169).pointee!
    let fn = unsafeBitCast(getStringUTFChars, to: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt8>?) -> UnsafePointer<CChar>?).self)

    guard let chars = fn(env, jstring, nil) else { return "" }
    let str = String(cString: chars)

    // ReleaseStringUTFChars is function #170
    let releaseStringUTFChars = functions.advanced(by: 170).pointee!
    let releaseFn = unsafeBitCast(releaseStringUTFChars, to: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void).self)
    releaseFn(env, jstring, chars)

    return str
}

/// Create a Java String via JNI.
func jniNewString(env: UnsafeMutableRawPointer, string: String) -> UnsafeMutableRawPointer? {
    let envPtr = env.assumingMemoryBound(to: UnsafeMutablePointer<UnsafeMutableRawPointer?>.self)
    let functions = envPtr.pointee

    // NewStringUTF is function #167
    let newStringUTF = functions.advanced(by: 167).pointee!
    let fn = unsafeBitCast(newStringUTF, to: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?).self)

    return string.withCString { cStr in
        fn(env, cStr)
    }
}
