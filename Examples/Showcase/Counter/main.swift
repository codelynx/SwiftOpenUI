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

struct CounterView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 8) {
            Text("Count: \(count)")
            Button("Increment") { count += 1 }
        }
        .padding()
    }
}

struct CounterApp: App {
    var body: some Scene {
        WindowGroup("Counter") {
            CounterView()
        }
    }
}

#if os(macOS)
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.activate(ignoringOtherApps: true)
CounterApp.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(CounterApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(CounterApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(CounterApp.self)
#else
print("Counter app defined. No backend available on this platform.")
#endif
