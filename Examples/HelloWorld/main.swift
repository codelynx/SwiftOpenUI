import SwiftOpenUI
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif

struct HelloWorldApp: App {
    var body: some Scene {
        WindowGroup("Hello World") {
            Text("Hello, SwiftOpenUI!")
                .padding()
        }
    }
}

#if canImport(BackendGTK4)
GTK4Backend().run(HelloWorldApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(HelloWorldApp.self)
#elseif os(macOS)
// On macOS, use the Xcode project in apple/ for real SwiftUI examples.
// SPM runners are for Linux/Windows backends.
print("HelloWorld: Use apple/Examples.xcodeproj on macOS, or run on Linux/Windows.")
#else
print("HelloWorld: No backend available on this platform.")
#endif
