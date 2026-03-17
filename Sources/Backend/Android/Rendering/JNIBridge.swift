import SwiftOpenUI

/// JNI entry point: renders a named example app to JSON.
/// Called from Kotlin: `RenderBridge().nativeRenderApp(name)`
///
/// JNI naming: Java_com_example_swiftopenui_RenderBridge_nativeRenderApp
@_cdecl("Java_com_example_swiftopenui_RenderBridge_nativeRenderApp")
public func jniRenderApp(
    env: UnsafeMutableRawPointer?,
    thisObj: UnsafeMutableRawPointer?,
    jName: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer? {
    guard let env = env, let jName = jName else { return nil }

    let name = jniGetString(env: env, jstring: jName)
    let json: String

    switch name {
    case "HelloWorld":
        json = renderExample {
            Text("Hello, SwiftOpenUI!")
                .padding()
        }
    case "TextStyles":
        json = renderTextStylesExample()
    case "Buttons":
        json = renderButtonsExample()
    case "StateDemo":
        json = renderStateDemoExample()
    case "Layout":
        json = renderLayoutExample()
    default:
        json = renderExample {
            Text("Unknown example: \(name)")
        }
    }

    return jniNewString(env: env, string: json)
}

/// Helper: render a simple view to JSON.
private func renderExample<V: View>(@ViewBuilder content: () -> V) -> String {
    let rootNode = androidRenderView(content())
    let wrapper = RenderNode(type: "window")
    wrapper.props["title"] = "SwiftOpenUI"
    wrapper.children = [rootNode]
    return renderNodeToJSON(wrapper)
}

// MARK: - Example renderers

private func renderTextStylesExample() -> String {
    renderExample {
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
    renderExample {
        VStack(spacing: 8) {
            Text("Buttons").font(.largeTitle)
            Button("Tap Me") { }
            Button("Red Button") { }
            Button("Green Button") { }
        }
        .padding()
    }
}

private func renderStateDemoExample() -> String {
    renderExample {
        VStack(spacing: 8) {
            Text("State Management").font(.largeTitle)
            Text("Count: 0")
            Button("Increment") { }
            Button("Reset") { }
        }
        .padding()
    }
}

private func renderLayoutExample() -> String {
    renderExample {
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
private func jniGetString(env: UnsafeMutableRawPointer, jstring: UnsafeMutableRawPointer) -> String {
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
private func jniNewString(env: UnsafeMutableRawPointer, string: String) -> UnsafeMutableRawPointer? {
    let envPtr = env.assumingMemoryBound(to: UnsafeMutablePointer<UnsafeMutableRawPointer?>.self)
    let functions = envPtr.pointee

    // NewStringUTF is function #167
    let newStringUTF = functions.advanced(by: 167).pointee!
    let fn = unsafeBitCast(newStringUTF, to: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?).self)

    return string.withCString { cStr in
        fn(env, cStr)
    }
}
