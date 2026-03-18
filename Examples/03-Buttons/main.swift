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

// MARK: - Buttons Demo

/// Demonstrates button variants: string label, custom label, actions.
struct ButtonsView: View {
    @State private var tapCount = 0
    @State private var lastAction = "None"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Buttons")
                .font(.title)
            Divider()

            Group {
                Text("String Label")
                    .font(.headline)
                Button("Tap Me") {
                    tapCount += 1
                }
                Text("Tapped \(tapCount) times")
            }

            Divider()

            Group {
                Text("Custom Label")
                    .font(.headline)
                Button(action: { lastAction = "Custom button tapped" }) {
                    HStack(spacing: 4) {
                        Text("★")
                            .foregroundColor(.yellow)
                        Text("Star Button")
                    }
                }
                Text("Last action: \(lastAction)")
            }

            Divider()

            Group {
                Text("Multiple Buttons")
                    .font(.headline)
                HStack(spacing: 8) {
                    Button("Red") { lastAction = "Red" }
                    Button("Green") { lastAction = "Green" }
                    Button("Blue") { lastAction = "Blue" }
                }
            }

            Spacer()
        }
        .padding()
    }
}

struct ButtonsApp: App {
    var body: some Scene {
        WindowGroup("03 - Buttons") {
            ButtonsView()
        }
    }
}

#if os(macOS)
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.activate(ignoringOtherApps: true)
ButtonsApp.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(ButtonsApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ButtonsApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ButtonsApp.self)
#else
print("Buttons app defined. No backend available on this platform.")
#endif
