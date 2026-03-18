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

/// Showcase2: Layout — VStack, HStack, ZStack, ForEach
struct Showcase2View: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Showcase 2: Layout")
                .font(.title)
            Divider()
            HStack(spacing: 16) {
                ForEach(0..<3) { index in
                    Text("Item \(index)")
                        .padding(4)
                        .background(.gray)
                }
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

struct Showcase2App: App {
    var body: some Scene {
        WindowGroup("Showcase 2") {
            Showcase2View()
        }
    }
}

#if os(macOS)
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.activate(ignoringOtherApps: true)
Showcase2App.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(Showcase2App.self)
#elseif canImport(BackendWin32)
Win32Backend().run(Showcase2App.self)
#elseif canImport(BackendWeb)
WebBackend().run(Showcase2App.self)
#else
print("Showcase2 app defined. No backend available on this platform.")
#endif
