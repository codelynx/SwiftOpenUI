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

// MARK: - State Demo

/// Counter — @State with Int
struct CounterSection: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("Counter")
                .font(.headline)
            Text("Count: \(count)")
            HStack(spacing: 8) {
                Button("−") { count -= 1 }
                Button("+") { count += 1 }
                Button("Reset") { count = 0 }
            }
        }
    }
}

/// Text toggle — @State with String
struct TextToggleSection: View {
    @State private var message = "Hello"

    var body: some View {
        VStack(spacing: 4) {
            Text("Text Toggle")
                .font(.headline)
            Text(message)
                .foregroundColor(.blue)
            Button("Toggle") {
                message = message == "Hello" ? "World" : "Hello"
            }
        }
    }
}

/// Conditional rendering — @State with Bool
struct ConditionalSection: View {
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 4) {
            Text("Conditional Rendering")
                .font(.headline)
            Button(showDetail ? "Hide Detail" : "Show Detail") {
                showDetail = !showDetail
            }
            if showDetail {
                Text("Here is the detail!")
                    .foregroundColor(.green)
                    .padding(4)
                    .background(.green.opacity(0.1))
            }
        }
    }
}

/// Binding — parent passes state to child
struct BindingChild: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("Child sees: \(value)")
            Button("Child +1") { value += 1 }
        }
    }
}

struct BindingSection: View {
    @State private var shared = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("@Binding (Parent ↔ Child)")
                .font(.headline)
            Text("Parent value: \(shared)")
            Button("Parent +1") { shared += 1 }
            BindingChild(value: $shared)
                .padding(4)
                .border(.gray)
        }
    }
}

/// Multiple @State properties
struct MultiStateSection: View {
    @State private var a = 0
    @State private var b = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("Multiple @State")
                .font(.headline)
            HStack(spacing: 16) {
                VStack {
                    Text("A: \(a)")
                    Button("A+") { a += 1 }
                }
                VStack {
                    Text("B: \(b)")
                    Button("B+") { b += 1 }
                }
            }
            Text("A + B = \(a + b)")
        }
    }
}

struct StateApp: App {
    var body: some Scene {
        WindowGroup("04 - State") {
            VStack(spacing: 12) {
                Text("State Management")
                    .font(.title)
                Divider()
                Group {
                    CounterSection()
                    Divider()
                    TextToggleSection()
                    Divider()
                    ConditionalSection()
                }
                Group {
                    Divider()
                    BindingSection()
                    Divider()
                    MultiStateSection()
                }
                Spacer()
            }
            .padding()
        }
    }
}

#if os(macOS)
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.activate(ignoringOtherApps: true)
StateApp.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(StateApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(StateApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(StateApp.self)
#else
print("State app defined. No backend available on this platform.")
#endif
