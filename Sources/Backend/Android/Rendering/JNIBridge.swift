import SwiftOpenUI

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
        androidCurrentHost = existing.host
        androidBeginRenderPass()
        let json = existing.host.buildBody()
        existing.host.pendingJSON = nil
        return jniNewString(env: env, string: json)
    }

    // Create a new session
    let host = createSessionForExample(name: name)
    currentSession = AndroidSession(host: host, exampleName: name)

    // Initial render
    androidCurrentHost = host
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

    // Clear pending state
    session.host.pendingJSON = nil
    session.host.needsRebuild = false

    // Look up and invoke the button's action closure.
    // The action may mutate @State, which sets needsRebuild = true.
    // The rebuild is deferred to here (not inside setValue) to avoid
    // stack overflow from deep JNI call chains.
    if let action = androidButtonActions[nodeId] {
        action()
    }

    // If state changed, rebuild now (outside the action's call stack)
    if session.host.needsRebuild {
        session.host.needsRebuild = false
        session.host.rebuild()
    }

    // Return new JSON if rebuild produced one
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

    // Clear pending state
    session.host.pendingJSON = nil
    session.host.needsRebuild = false

    // Update the binding — this triggers @State mutation → needsRebuild = true
    if let binding = androidTextBindings[nodeId] {
        binding.wrappedValue = newText
    }

    // Deferred rebuild (same pattern as nativeOnButtonClick)
    if session.host.needsRebuild {
        session.host.needsRebuild = false
        session.host.rebuild()
    }

    // If @State changed, return the new tree
    if let json = session.host.pendingJSON {
        session.host.pendingJSON = nil
        return jniNewString(env: env, string: json)
    }

    return nil
}

/// Handle a toggle change event. Updates the Toggle's @Binding<Bool>.
/// Returns new JSON if the tree was rebuilt, or null if no state changed.
///
/// Called from Kotlin: `RenderBridge.nativeOnToggleChange(nodeId, isOn)`
@_cdecl("Java_com_example_swiftopenui_RenderBridge_nativeOnToggleChange")
public func jniOnToggleChange(
    env: UnsafeMutableRawPointer?,
    thisObj: UnsafeMutableRawPointer?,
    nodeId: Int64,
    isOn: UInt8
) -> UnsafeMutableRawPointer? {
    guard let env = env, let session = currentSession else { return nil }

    session.host.pendingJSON = nil
    session.host.needsRebuild = false

    if let binding = androidToggleBindings[nodeId] {
        binding.wrappedValue = (isOn != 0)
    }

    if session.host.needsRebuild {
        session.host.needsRebuild = false
        session.host.rebuild()
    }

    if let json = session.host.pendingJSON {
        session.host.pendingJSON = nil
        return jniNewString(env: env, string: json)
    }

    return nil
}

/// Handle a slider change event. Updates the Slider's @Binding<Double>.
/// Returns new JSON if the tree was rebuilt, or null if no state changed.
///
/// Called from Kotlin: `RenderBridge.nativeOnSliderChange(nodeId, value)`
@_cdecl("Java_com_example_swiftopenui_RenderBridge_nativeOnSliderChange")
public func jniOnSliderChange(
    env: UnsafeMutableRawPointer?,
    thisObj: UnsafeMutableRawPointer?,
    nodeId: Int64,
    value: Double
) -> UnsafeMutableRawPointer? {
    guard let env = env, let session = currentSession else { return nil }

    session.host.pendingJSON = nil
    session.host.needsRebuild = false

    if let binding = androidSliderBindings[nodeId] {
        binding.wrappedValue = value
    }

    if session.host.needsRebuild {
        session.host.needsRebuild = false
        session.host.rebuild()
    }

    if let json = session.host.pendingJSON {
        session.host.pendingJSON = nil
        return jniNewString(env: env, string: json)
    }

    return nil
}

/// Handle a drag gesture event from Kotlin.
/// Called continuously during drag (onChanged) and once at end (onEnded).
/// Drag events do NOT trigger rebuilds — the callback updates @State which does.
///
/// Called from Kotlin: `RenderBridge.nativeOnDragEvent(nodeId, phase, startX, startY, currentX, currentY)`
@_cdecl("Java_com_example_swiftopenui_RenderBridge_nativeOnDragEvent")
public func jniOnDragEvent(
    env: UnsafeMutableRawPointer?,
    thisObj: UnsafeMutableRawPointer?,
    nodeId: Int64,
    phase: Int32,  // 0 = changed, 1 = ended
    startX: Double, startY: Double,
    currentX: Double, currentY: Double
) -> UnsafeMutableRawPointer? {
    guard let env = env, let session = currentSession else { return nil }

    session.host.pendingJSON = nil
    session.host.needsRebuild = false

    if let handler = androidDragHandlers[nodeId] {
        let value = DragGestureValue(
            startLocation: (x: startX, y: startY),
            location: (x: currentX, y: currentY),
            translation: (width: currentX - startX, height: currentY - startY)
        )
        if phase == 0 {
            handler.onChanged?(value)
        } else {
            handler.onEnded?(value)
        }
    }

    // If the callback mutated @State, rebuild
    if session.host.needsRebuild {
        session.host.needsRebuild = false
        session.host.rebuild()
    }

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
    case "NavigationDemo":
        return createNavigationDemoSession()
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
/// Uses a flat view with all @State on one struct because Android
/// doesn't yet persist @State in nested composed child views.
private func createStateDemoSession() -> AndroidViewHost {
    var view = AndroidStateDemoView() // swiftlint:disable:this redundant_var

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

/// State demo — uses nested child views with their own @State.
/// The structural state cache preserves child @State across rebuilds.
private struct AndroidStateDemoView: View {
    @State var shared: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("State Management").font(.title)
            Divider()
            NestedCounterSection()
            Divider()
            NestedToggleSection()
            Divider()
            VStack(spacing: 4) {
                Text("@Binding").font(.headline)
                Text("Parent value: \(shared)")
                Button("Parent +1") { shared += 1 }
                HStack(spacing: 8) {
                    Text("Child sees: \(shared)")
                    Button("Child +1") { shared += 1 }
                }.padding(4)
            }
            Divider()
            NestedMultiSection()
        }.padding()
    }
}

/// Nested child view with its own @State — tests structural state cache.
private struct NestedCounterSection: View {
    @State var count: Int = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("Counter (nested @State)").font(.headline)
            Text("Count: \(count)")
            HStack(spacing: 8) {
                Button("−") { count -= 1 }
                Button("+") { count += 1 }
                Button("Reset") { count = 0 }
            }
        }
    }
}

/// Nested child view with its own @State.
private struct NestedToggleSection: View {
    @State var message: String = "Hello"
    @State var showDetail: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text("Toggle (nested @State)").font(.headline)
            Text(message).foregroundColor(.blue)
            Button("Toggle") { message = message == "Hello" ? "World" : "Hello" }
            Button(showDetail ? "Hide Detail" : "Show Detail") { showDetail = !showDetail }
            if showDetail {
                Text("Here is the detail!").foregroundColor(.green).padding(4)
            }
        }
    }
}

/// Nested child view with multiple @State properties.
private struct NestedMultiSection: View {
    @State var a: Int = 0
    @State var b: Int = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("Multiple @State (nested)").font(.headline)
            HStack(spacing: 16) {
                VStack { Text("A: \(a)"); Button("A+") { a += 1 } }
                VStack { Text("B: \(b)"); Button("B+") { b += 1 } }
            }
            Text("A + B = \(a + b)")
        }
    }
}

// MARK: - Navigation demo

private func createNavigationDemoSession() -> AndroidViewHost {
    var view = AndroidNavigationDemo() // swiftlint:disable:this redundant_var

    let host = AndroidViewHost { [view] in
        androidBeginRenderPass()
        let rootNode = androidRenderView(view)
        let wrapper = RenderNode(type: "window")
        wrapper.props["title"] = "SwiftOpenUI"
        wrapper.children = [rootNode]
        return renderNodeToJSON(wrapper)
    }

    installState(view, host: host)
    return host
}

/// Flat navigation demo — all @State on one struct for Android.
/// Demonstrates NavigationPath binding with programmatic push/pop.
private struct AndroidNavigationDemo: View {
    @State var path: NavigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 12) {
                Text("Navigation Path Demo").font(.title)
                Divider()
                Text("Path depth: \(path.count)")
                NavigationLink("Go to Page A", title: "Page A") {
                    VStack(spacing: 8) {
                        Text("Detail: Page A").font(.title)
                        Text("You navigated here via NavigationLink.")
                    }
                    .padding()
                }
                NavigationLink("Go to Page B", title: "Page B") {
                    VStack(spacing: 8) {
                        Text("Detail: Page B").font(.title)
                        Text("You navigated here via NavigationLink.")
                    }
                    .padding()
                }
                Divider()
                Text("Programmatic Navigation").font(.headline)
                Button("Push 'Settings'") { path.append("Settings") }
                Button("Push 'Profile'") { path.append("Profile") }
                if !path.isEmpty {
                    Button("Pop") { path.removeLast() }
                    Button("Pop to Root") { path.removeLast(path.count) }
                }
            }
            .padding()
            .navigationTitle("Home")
        }
        .navigationDestination(for: String.self) { value in
            VStack(spacing: 8) {
                Text("Detail: \(value)").font(.title)
                Text("Pushed via NavigationPath")
                Text("Path depth: \(path.count)")
                Button("Push 'Sub-page'") { path.append("Sub-\(value)") }
                Button("Pop") { path.removeLast() }
                Button("Pop to Root") { path.removeLast(path.count) }
            }
            .padding()
        }
    }
}

// MARK: - TextField demo

private func createTextFieldDemoSession() -> AndroidViewHost {
    var view = AndroidTextFieldDemo() // swiftlint:disable:this redundant_var

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

/// TextField + FocusState demo — demonstrates TextField binding and @FocusState on Android.
private struct AndroidTextFieldDemo: View {
    enum Field { case name, email }

    @State var name: String = ""
    @State var email: String = ""
    @State var counter: Int = 0
    @FocusState var focusedField: Field?

    var body: some View {
        VStack(spacing: 12) {
            Text("TextField + Focus Demo").font(.title)
            Divider()
            VStack(spacing: 4) {
                Text("Name").font(.headline)
                TextField("Enter your name", text: $name)
                    .focused($focusedField, equals: .name)
                Text("Hello, \(name.isEmpty ? "stranger" : name)!")
                    .foregroundColor(.blue)
            }
            Divider()
            VStack(spacing: 4) {
                Text("Email").font(.headline)
                TextField("Enter your email", text: $email)
                    .focused($focusedField, equals: .email)
                if !email.isEmpty {
                    Text("Email: \(email)")
                        .foregroundColor(.green)
                }
            }
            Divider()
            VStack(spacing: 4) {
                Text("Programmatic Focus").font(.headline)
                HStack(spacing: 8) {
                    Button("Focus Name") { focusedField = .name }
                    Button("Focus Email") { focusedField = .email }
                    Button("Clear Focus") { focusedField = nil }
                }
            }
            Divider()
            VStack(spacing: 4) {
                Text("Combined").font(.headline)
                if !name.isEmpty && !email.isEmpty {
                    Text("\(name) <\(email)>")
                }
                Button("Clear All") {
                    name = ""
                    email = ""
                }
            }
            Divider()
            VStack(spacing: 4) {
                Text("Rebuild Test").font(.headline)
                Text("Counter: \(counter)")
                Button("Increment (triggers rebuild)") { counter += 1 }
            }
        }
        .padding()
    }
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
