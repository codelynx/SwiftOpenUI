#if os(macOS)
import SwiftUI
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

/// Showcase1: Basic views — Text, Button, Spacer, Divider, Color
struct Showcase1View: View {
    @State private var message = "Hello"

    var body: some View {
        VStack(spacing: 8) {
            Text("Showcase 1: Basic Views")
                .font(.title)
            Divider()
            Text(message)
                .foregroundColor(.blue)
            Button("Change Message") {
                message = message == "Hello" ? "World" : "Hello"
            }
            Spacer()
        }
        .padding()
    }
}

struct Showcase1App: App {
    var body: some Scene {
        WindowGroup("Showcase 1") {
            Showcase1View()
        }
    }
}

#if os(macOS)
Showcase1App.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(Showcase1App.self)
#elseif canImport(BackendWin32)
Win32Backend().run(Showcase1App.self)
#elseif canImport(BackendWeb)
WebBackend().run(Showcase1App.self)
#else
print("Showcase1 app defined. No backend available on this platform.")
#endif
