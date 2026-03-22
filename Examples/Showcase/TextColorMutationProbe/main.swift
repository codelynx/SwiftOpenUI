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

struct ProbeSwatch: View {
    let color: Color

    var body: some View {
        color
            .frame(width: 96, height: 56)
            .border(Color(red: 0.35, green: 0.35, blue: 0.35))
    }
}

struct TextColorMutationProbeView: View {
    @State private var title = "Alpha"
    @State private var bareSwatch = Color(red: 0.2, green: 0.4, blue: 0.8)
    @State private var bareSwatchToggle = false
    @State private var swatch = Color(red: 0.2, green: 0.4, blue: 0.8)
    @State private var swatchToggle = false
    @State private var padding = 8

    var body: some View {
        VStack(spacing: 12) {
            Text("Text/Color Host Mutation Probe")
                .font(.headline)

            Text("Supported path")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 22, weight: .medium))

                    Text("Bare Color")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))

                    bareSwatch

                    Text("Wrapped Color")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))

                    ProbeSwatch(color: swatch)
                }

                Spacer()
            }

            Divider()

            Text("Fallback path")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))

            Text("Padding = \(padding)")
                .padding(CGFloat(padding))
                .border(Color(red: 0.6, green: 0.6, blue: 0.6))

            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: {
                        title = title == "Alpha" ? "Bravo" : "Alpha"
                    }) {
                        Text("Change Text")
                            .frame(width: 120, height: 32)
                            .foregroundColor(.white)
                            .background(Color(red: 0.18, green: 0.42, blue: 0.76))
                    }

                    Button(action: {
                        bareSwatchToggle.toggle()
                        bareSwatch = bareSwatchToggle
                            ? Color(red: 0.2, green: 0.4, blue: 0.8)
                            : Color(red: 0.88, green: 0.28, blue: 0.22)
                    }) {
                        Text("Change Bare")
                            .frame(width: 120, height: 32)
                            .foregroundColor(.white)
                            .background(Color(red: 0.17, green: 0.55, blue: 0.7))
                    }
                }

                HStack(spacing: 8) {
                    Button(action: {
                        swatchToggle.toggle()
                        swatch = swatchToggle
                            ? Color(red: 0.2, green: 0.4, blue: 0.8)
                            : Color(red: 0.88, green: 0.28, blue: 0.22)
                    }) {
                        Text("Change Wrapped")
                            .frame(width: 120, height: 32)
                            .foregroundColor(.white)
                            .background(Color(red: 0.15, green: 0.6, blue: 0.32))
                    }

                    Button(action: {
                        title = title == "Alpha" ? "Bravo" : "Alpha"
                        bareSwatchToggle.toggle()
                        bareSwatch = bareSwatchToggle
                            ? Color(red: 0.2, green: 0.4, blue: 0.8)
                            : Color(red: 0.88, green: 0.28, blue: 0.22)
                        swatchToggle.toggle()
                        swatch = swatchToggle
                            ? Color(red: 0.2, green: 0.4, blue: 0.8)
                            : Color(red: 0.88, green: 0.28, blue: 0.22)
                    }) {
                        Text("Change Both")
                            .frame(width: 120, height: 32)
                            .foregroundColor(.white)
                            .background(Color(red: 0.55, green: 0.34, blue: 0.16))
                    }

                    Button(action: {
                        padding = padding == 8 ? 20 : 8
                    }) {
                        Text("Change Padding")
                            .frame(width: 120, height: 32)
                            .foregroundColor(.white)
                            .background(Color(red: 0.58, green: 0.18, blue: 0.18))
                    }
                }
            }

            Text("Expected: text, bare color, and wrapped color mutate in place; padding falls back to rebuild.")
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
        }
        .frame(minWidth: 520, minHeight: 340)
        .padding()
        .background(Color(red: 0.96, green: 0.96, blue: 0.96))
    }
}

struct TextColorMutationProbeApp: App {
    var body: some Scene {
        WindowGroup("Text Color Mutation Probe") {
            TextColorMutationProbeView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(TextColorMutationProbeApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(TextColorMutationProbeApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(TextColorMutationProbeApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(TextColorMutationProbeApp.self)
#else
print("TextColorMutationProbe app defined. No backend available on this platform.")
#endif
