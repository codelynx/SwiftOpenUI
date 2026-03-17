// JNI entry point — called from Kotlin via System.loadLibrary("SwiftHello")
//
// JNI function naming: Java_<package>_<class>_<method>
// Package: com.example.swifthello
// Class: MainActivity
// Method: helloFromSwift

@_cdecl("Java_com_example_swifthello_MainActivity_helloFromSwift")
public func helloFromSwift(
    env: UnsafeMutableRawPointer?,
    thisObj: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer? {
    let message = "Hello from SwiftOpenUI on Android!"
    return createJavaString(env: env, string: message)
}

/// Create a Java String from a Swift String via JNI NewStringUTF.
private func createJavaString(env: UnsafeMutableRawPointer?, string: String) -> UnsafeMutableRawPointer? {
    guard let env = env else { return nil }

    // JNIEnv is a pointer to a function table.
    // JNIEnv** -> JNINativeInterface** -> NewStringUTF is at index 167
    let envPtr = env.assumingMemoryBound(to: UnsafeMutablePointer<UnsafeMutableRawPointer?>.self)
    let functions = envPtr.pointee

    // NewStringUTF is function #167 in the JNI function table
    let newStringUTF = functions.advanced(by: 167).pointee!
    let fn = unsafeBitCast(newStringUTF, to: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?).self)

    return string.withCString { cStr in
        fn(env, cStr)
    }
}
