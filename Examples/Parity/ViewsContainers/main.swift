// Parity: Views — Containers
// Owner: List, ScrollView, Toggle, Slider, Image (system), Image (file)
// See: docs/architecture/swiftui-parity-matrix.md § Views

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

struct ParityViewsContainersView: View {
    @State private var toggleValue = true
    @State private var sliderValue: Double = 50
    @State private var itemCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parity: Views — Containers")
                .font(.headline)
                .padding(.bottom, 4)

            // MARK: - Toggle

            VStack(alignment: .leading, spacing: 4) {
                Text("Toggle")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Toggle("Enabled", isOn: $toggleValue)
                Text("Value: \(toggleValue ? "ON" : "OFF")")
                    .foregroundColor(toggleValue ? .green : .red)
            }

            Divider()

            // MARK: - Slider

            VStack(alignment: .leading, spacing: 4) {
                Text("Slider")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack {
                    Slider(value: $sliderValue, in: 0...100, step: 1)
                    Text("\(Int(sliderValue))")
                        .frame(width: 32)
                }
                // Visual bar driven by slider
                Color.blue
                    .frame(width: sliderValue * 2, height: 8)
            }

            Divider()

            // MARK: - Image (system)

            VStack(alignment: .leading, spacing: 4) {
                Text("Image (system)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                #if os(macOS)
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                    Image(systemName: "heart.fill")
                    Image(systemName: "gear")
                }
                #elseif canImport(BackendWin32)
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Image(systemName: "exclamationmark.triangle")
                    Image(systemName: "shield")
                }
                Text("(Win32 stock icons)")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                #else
                HStack(spacing: 8) {
                    Image(systemName: "starred")
                    Image(systemName: "emblem-favorite")
                    Image(systemName: "preferences-system")
                }
                Text("(GTK icon theme names)")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                #endif
            }

            Divider()

            // MARK: - Image (file)

            VStack(alignment: .leading, spacing: 4) {
                Text("Image (file)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("(Requires a valid file path on the platform)")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
            }

            Divider()

            // MARK: - ScrollView

            VStack(alignment: .leading, spacing: 4) {
                Text("ScrollView")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(0..<10) { i in
                            Text("Scroll item \(i)")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .frame(height: 80)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
            }

            Divider()

            // MARK: - List

            VStack(alignment: .leading, spacing: 4) {
                Text("List")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    Button("-") { if itemCount > 0 { itemCount -= 1 } }
                    Button("+") { if itemCount < 8 { itemCount += 1 } }
                    Text("\(itemCount) items")
                        .foregroundColor(.gray)
                }
                List {
                    ForEach(0..<itemCount, id: \.self) { i in
                        Text("List item \(i)")
                    }
                }
                .frame(height: 80)
            }

            Spacer()
        }
        .padding()
    }
}

struct ParityViewsContainersApp: App {
    var body: some Scene {
        WindowGroup("Parity: Views Containers") {
            ParityViewsContainersView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityViewsContainersApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityViewsContainersApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityViewsContainersApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityViewsContainersApp.self)
#else
print("ParityViewsContainers defined. No backend available on this platform.")
#endif
