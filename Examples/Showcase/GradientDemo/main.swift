// Gradient rendering demo — doubles as reproducible render evidence for the GTK4
// LinearGradient fix. LinearGradient/RadialGradient share SwiftUI's inits, so this
// validates against real SwiftUI on macOS too.
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

struct GradientDemoView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("LinearGradient — to right (blue→indigo)")
            LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
                .frame(height: 40)
            Text("LinearGradient — 135° (green→teal), rounded")
            LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("RadialGradient (orange→red)")
            RadialGradient(colors: [.orange, .red], center: .center, startRadius: 4, endRadius: 140)
                .frame(height: 80)
        }
        .padding(16)
        .frame(minWidth: 380, minHeight: 320)
    }
}

struct GradientDemoApp: App {
    var body: some Scene { WindowGroup("Gradient Demo") { GradientDemoView() } }
}

#if os(macOS)
MacAppLauncher.run(GradientDemoApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(GradientDemoApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(GradientDemoApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(GradientDemoApp.self)
#endif
