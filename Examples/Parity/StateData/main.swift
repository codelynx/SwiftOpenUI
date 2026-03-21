// Parity: State & Data
// Owner: @State, @Binding, @ObservedObject, @StateObject, @Published, ObservableObject
// See: docs/architecture/swiftui-parity-matrix.md § State & Data

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

// MARK: - @Published / ObservableObject
// Validated by: class drives Text update on button tap

#if os(macOS)
class ItemStore: ObservableObject {
    @Published var count = 0
    @Published var label = "Ready"
}
#else
class ItemStore: SwiftOpenUI.ObservableObject {
    @SwiftOpenUI.Published var count = 0
    @SwiftOpenUI.Published var label = "Ready"
}
#endif

// MARK: - Child views (pure, no local @State)

struct BindingDemo: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("Child sees: \(value)")
            Button("+1 from child") { value += 1 }
        }
    }
}

struct ObservedObjectDemo: View {
    #if os(macOS)
    @ObservedObject var store: ItemStore
    #else
    @SwiftOpenUI.ObservedObject var store: ItemStore
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Store count: \(store.count)")
            Text("Store label: \(store.label)")
            Button("Increment store") {
                store.count += 1
                store.label = "Count is \(store.count)"
            }
        }
    }
}

struct ParityStateDataView: View {
    // All @State on root
    @State private var counter = 0
    @State private var text = "Hello"
    @State private var flag = true
    @State private var bindingValue = 0

    #if os(macOS)
    @StateObject private var store = ItemStore()
    #else
    @SwiftOpenUI.StateObject private var store = ItemStore()
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parity: State & Data")
                .font(.headline)
                .padding(.bottom, 4)

            // MARK: - @State

            VStack(alignment: .leading, spacing: 4) {
                Text("@State")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                // Int
                HStack {
                    Text("Counter: \(counter)")
                    Button("-") { counter -= 1 }
                    Button("+") { counter += 1 }
                }

                // String
                HStack {
                    Text("Text: \(text)")
                    Button("Toggle text") {
                        text = text == "Hello" ? "World" : "Hello"
                    }
                }

                // Bool driving conditional
                HStack {
                    Text("Flag: \(flag ? "ON" : "OFF")")
                    Button("Toggle") { flag.toggle() }
                }
                if flag {
                    Text("Visible when flag is ON")
                        .foregroundColor(.green)
                } else {
                    Text("Visible when flag is OFF")
                        .foregroundColor(.red)
                }
            }

            Divider()

            // MARK: - @Binding

            VStack(alignment: .leading, spacing: 4) {
                Text("@Binding")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Parent value: \(bindingValue)")
                BindingDemo(value: $bindingValue)
                Button("+1 from parent") { bindingValue += 1 }
            }

            Divider()

            // MARK: - @StateObject / @ObservedObject / @Published

            VStack(alignment: .leading, spacing: 4) {
                Text("@StateObject + @ObservedObject + @Published")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("@StateObject owns the store (survives rebuilds)")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                ObservedObjectDemo(store: store)
            }

            Spacer()
        }
        .padding()
    }
}

struct ParityStateDataApp: App {
    var body: some Scene {
        WindowGroup("Parity: State & Data") {
            ParityStateDataView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityStateDataApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityStateDataApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityStateDataApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityStateDataApp.self)
#else
print("ParityStateData defined. No backend available on this platform.")
#endif
