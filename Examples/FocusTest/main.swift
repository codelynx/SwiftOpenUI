#if os(macOS)
import SwiftUI
import AppKit
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

struct FocusTestView: View {
    @State private var name = ""
    @State private var counter = 0

    var body: some View {
        VStack(spacing: 8) {
            Text("Type in the field, then click the button.")
                .font(.headline)
            Text("Cursor should stay in place after rebuild.")
            Divider()
            TextField("Type here...", text: $name)
            Text("You typed: \(name)")
            Text("Counter: \(counter)")
            Button("Increment (triggers rebuild)") { counter += 1 }
        }
        .padding()
    }
}

struct FocusTestApp: App {
    var body: some Scene {
        WindowGroup("Focus Preservation Test") {
            FocusTestView()
        }
    }
}

#if os(macOS)
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.activate(ignoringOtherApps: true)
FocusTestApp.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(FocusTestApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(FocusTestApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(FocusTestApp.self)
#else
print("FocusTest app defined. No backend available on this platform.")
#endif
