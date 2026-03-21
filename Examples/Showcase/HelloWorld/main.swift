#if os(macOS)
import SwiftUI
import MacExampleSupport
#else
import SwiftOpenUI
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif
#if canImport(BackendWeb)
import BackendWeb
#endif
#endif

struct HelloWorldApp: App {
    var body: some Scene {
        WindowGroup("Hello World") {
            Text("Hello, SwiftOpenUI!")
                .padding()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(HelloWorldApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(HelloWorldApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(HelloWorldApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(HelloWorldApp.self)
#else
print("HelloWorld app defined. No backend available on this platform.")
#endif
