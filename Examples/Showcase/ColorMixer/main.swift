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

// MARK: - Color Utilities

struct RGB {
    var r: Double  // 0–255
    var g: Double
    var b: Double

    var hex: String {
        String(format: "#%02X%02X%02X", Int(r), Int(g), Int(b))
    }

    var color: Color {
        Color(red: r / 255.0, green: g / 255.0, blue: b / 255.0)
    }

    var complementary: RGB {
        RGB(r: 255 - r, g: 255 - g, b: 255 - b)
    }

    var analogous: (RGB, RGB) {
        // Shift hue ±30° via simple RGB rotation approximation
        let shift: Double = 40
        let left = RGB(
            r: clamp(r - shift), g: clamp(g + shift * 0.5), b: clamp(b + shift * 0.5))
        let right = RGB(
            r: clamp(r + shift * 0.5), g: clamp(g - shift), b: clamp(b + shift * 0.5))
        return (left, right)
    }

    func lighter(by amount: Double = 30) -> RGB {
        RGB(r: clamp(r + amount), g: clamp(g + amount), b: clamp(b + amount))
    }

    func darker(by amount: Double = 30) -> RGB {
        RGB(r: clamp(r - amount), g: clamp(g - amount), b: clamp(b - amount))
    }

    private func clamp(_ v: Double) -> Double {
        min(255, max(0, v))
    }
}

let presetSwatches: [RGB] = [
    RGB(r: 235, g:  64, b:  52),  // Red
    RGB(r: 245, g: 166, b:  35),  // Orange
    RGB(r: 248, g: 231, b:  28),  // Yellow
    RGB(r:  80, g: 200, b:  80),  // Green
    RGB(r:  24, g: 160, b: 251),  // Blue
    RGB(r: 126, g:  87, b: 194),  // Purple
    RGB(r: 255, g: 255, b: 255),  // White
    RGB(r: 158, g: 158, b: 158),  // Gray
    RGB(r:  66, g:  66, b:  66),  // Dark Gray
    RGB(r:   0, g:   0, b:   0),  // Black
    RGB(r: 255, g: 183, b: 197),  // Pink
    RGB(r:   0, g: 150, b: 136),  // Teal
]

// MARK: - Color Studio View

struct ColorStudioView: View {
    static let windowWidth = 320.0
    static let windowHeight = 450.0

    @State private var red: Double = 80
    @State private var green: Double = 160
    @State private var blue: Double = 220

    private var current: RGB { RGB(r: red, g: green, b: blue) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Color Studio")
                .font(.headline)
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Large swatch + values
            HStack(spacing: 12) {
                current.color
                    .frame(width: 120, height: 80)
                    .border(Color(red: 0.3, green: 0.3, blue: 0.3))

                VStack(alignment: .leading, spacing: 4) {
                    Text(current.hex)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                    Text("R: \(Int(red))  G: \(Int(green))  B: \(Int(blue))")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                    // HSB approximation display
                    Text(String(format: "%.0f%% brightness",
                                (red + green + blue) / 7.65))
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // RGB Sliders
            VStack(spacing: 6) {
                SliderRow(label: "R", value: $red,
                          trackColor: Color(red: 0.8, green: 0.2, blue: 0.2))
                SliderRow(label: "G", value: $green,
                          trackColor: Color(red: 0.2, green: 0.7, blue: 0.2))
                SliderRow(label: "B", value: $blue,
                          trackColor: Color(red: 0.2, green: 0.4, blue: 0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Preset palette
            Text("Swatches")
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                .padding(.top, 8)

            // Row 1
            HStack(spacing: 4) {
                ForEach(0..<6) { i in
                    presetSwatches[i].color
                        .frame(width: 28, height: 28)
                        .border(Color(red: 0.3, green: 0.3, blue: 0.3))
                        .onTapGesture {
                            red = presetSwatches[i].r
                            green = presetSwatches[i].g
                            blue = presetSwatches[i].b
                        }
                }
            }
            .padding(.top, 4)

            // Row 2
            HStack(spacing: 4) {
                ForEach(6..<12) { i in
                    presetSwatches[i].color
                        .frame(width: 28, height: 28)
                        .border(Color(red: 0.3, green: 0.3, blue: 0.3))
                        .onTapGesture {
                            red = presetSwatches[i].r
                            green = presetSwatches[i].g
                            blue = presetSwatches[i].b
                        }
                }
            }
            .padding(.top, 2)

            Divider()
                .padding(.top, 8)

            // Lighter / Darker buttons
            HStack(spacing: 12) {
                Button(action: {
                    let l = current.lighter()
                    red = l.r; green = l.g; blue = l.b
                }) {
                    Text("Lighter")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 70, height: 28)
                        .background(Color(red: 0.3, green: 0.3, blue: 0.3))
                }
                Button(action: {
                    let d = current.darker()
                    red = d.r; green = d.g; blue = d.b
                }) {
                    Text("Darker")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 70, height: 28)
                        .background(Color(red: 0.3, green: 0.3, blue: 0.3))
                }
            }
            .padding(.vertical, 8)

            Divider()

            // Color harmony
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("Complementary")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    HStack(spacing: 4) {
                        current.color
                            .frame(width: 24, height: 24)
                        current.complementary.color
                            .frame(width: 24, height: 24)
                    }
                }

                VStack(spacing: 2) {
                    Text("Analogous")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    HStack(spacing: 4) {
                        current.analogous.0.color
                            .frame(width: 24, height: 24)
                        current.color
                            .frame(width: 24, height: 24)
                        current.analogous.1.color
                            .frame(width: 24, height: 24)
                    }
                }

                VStack(spacing: 2) {
                    Text("Shades")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    HStack(spacing: 4) {
                        current.darker(by: 50).color
                            .frame(width: 24, height: 24)
                        current.color
                            .frame(width: 24, height: 24)
                        current.lighter(by: 50).color
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(.vertical, 8)

            Spacer()
        }
        .frame(width: Self.windowWidth, height: Self.windowHeight)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let trackColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(trackColor)
                .frame(width: 16)
            Slider(value: $value, in: 0...255, step: 1)
            Text("\(Int(value))")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .frame(width: 32)
        }
    }
}

// MARK: - App

struct ColorMixerApp: App {
    var body: some Scene {
        #if os(macOS)
        WindowGroup("Color Studio") {
            ColorStudioView()
        }
        .windowResizability(.contentSize)
        #else
        WindowGroup("Color Studio") {
            ColorStudioView()
        }
        .defaultWindowSize(
            width: ColorStudioView.windowWidth,
            height: ColorStudioView.windowHeight
        )
        .windowSizing(.contentFixed)
        #endif
    }
}

#if os(macOS)
MacAppLauncher.run(ColorMixerApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ColorMixerApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ColorMixerApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ColorMixerApp.self)
#else
print("Color Studio app defined. No backend available on this platform.")
#endif
