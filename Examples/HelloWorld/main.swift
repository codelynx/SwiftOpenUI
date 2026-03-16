#if os(macOS)
import SwiftUI
#else
import SwiftOpenUI
#if canImport(BackendGTK4)
import BackendGTK4
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
HelloWorldApp.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(HelloWorldApp.self)
#else
print("HelloWorld app defined. No backend available on this platform.")
#endif
