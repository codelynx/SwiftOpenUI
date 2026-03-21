// Parity: Environment
// Owner: @Environment, @EnvironmentObject, .environmentObject(),
//        .environment(), custom EnvironmentKey
// See: docs/architecture/swiftui-parity-matrix.md § State & Data + § Modifiers

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

// MARK: - Custom EnvironmentKey

private struct AccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .blue
}

extension EnvironmentValues {
    var accentColor: Color {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }
}

// MARK: - EnvironmentObject model

#if os(macOS)
class ThemeSettings: ObservableObject {
    @Published var isDark = true
    @Published var fontSize: Double = 14
}
#else
class ThemeSettings: SwiftOpenUI.ObservableObject {
    @SwiftOpenUI.Published var isDark = true
    @SwiftOpenUI.Published var fontSize: Double = 14
}
#endif

// MARK: - Child views (pure, read from environment)

struct AccentColorReader: View {
    @Environment(\.accentColor) var accent: Color

    var body: some View {
        Text("Custom accent color from environment")
            .foregroundColor(accent)
    }
}

struct ThemeReader: View {
    #if os(macOS)
    @EnvironmentObject var theme: ThemeSettings
    #else
    @SwiftOpenUI.EnvironmentObject var theme: ThemeSettings
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Theme: \(theme.isDark ? "Dark" : "Light")")
                .font(.system(size: theme.fontSize))
            Text("Font size: \(Int(theme.fontSize))pt")
                .foregroundColor(.gray)
        }
    }
}

struct NestedEnvReader: View {
    @Environment(\.accentColor) var accent: Color

    var body: some View {
        Text("Nested child sees accent")
            .foregroundColor(accent)
    }
}

// MARK: - Root view

struct ParityEnvironmentView: View {
    @State private var useRed = false

    #if os(macOS)
    @StateObject private var theme = ThemeSettings()
    #else
    @SwiftOpenUI.StateObject private var theme = ThemeSettings()
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parity: Environment")
                .font(.headline)
                .padding(.bottom, 4)

            // MARK: - .environment() + @Environment (custom key)

            VStack(alignment: .leading, spacing: 4) {
                Text(".environment() + @Environment")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                // Default value
                AccentColorReader()

                // Overridden value
                AccentColorReader()
                    .environment(\.accentColor, .red)

                // Toggle override
                Button("Toggle accent") { useRed.toggle() }
                AccentColorReader()
                    .environment(\.accentColor, useRed ? .red : .green)
            }

            Divider()

            // MARK: - .environmentObject() + @EnvironmentObject

            VStack(alignment: .leading, spacing: 4) {
                Text(".environmentObject() + @EnvironmentObject")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                ThemeReader()
                    .environmentObject(theme)

                HStack(spacing: 8) {
                    Button("Toggle dark") { theme.isDark.toggle() }
                    Button("Size +") { theme.fontSize += 2 }
                    Button("Size -") { if theme.fontSize > 8 { theme.fontSize -= 2 } }
                }
            }

            Divider()

            // MARK: - Environment propagation

            VStack(alignment: .leading, spacing: 4) {
                Text("Environment propagation")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Parent sets .environment, nested child reads it:")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))

                VStack(alignment: .leading) {
                    NestedEnvReader()
                }
                .environment(\.accentColor, .orange)
            }

            Spacer()
        }
        .padding()
    }
}

struct ParityEnvironmentApp: App {
    var body: some Scene {
        WindowGroup("Parity: Environment") {
            ParityEnvironmentView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityEnvironmentApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityEnvironmentApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityEnvironmentApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityEnvironmentApp.self)
#else
print("ParityEnvironment defined. No backend available on this platform.")
#endif
