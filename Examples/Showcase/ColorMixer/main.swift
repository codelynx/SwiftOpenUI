#if os(macOS)
import SwiftUI
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

struct ColorPreset {
    let name: String
    let r: Double
    let g: Double
    let b: Double
}

let presets: [ColorPreset] = [
    ColorPreset(name: "Red",     r: 255, g: 0,   b: 0),
    ColorPreset(name: "Green",   r: 0,   g: 200, b: 0),
    ColorPreset(name: "Blue",    r: 0,   g: 0,   b: 255),
    ColorPreset(name: "Yellow",  r: 255, g: 255, b: 0),
    ColorPreset(name: "Cyan",    r: 0,   g: 255, b: 255),
    ColorPreset(name: "Magenta", r: 255, g: 0,   b: 255),
    ColorPreset(name: "Orange",  r: 255, g: 165, b: 0),
    ColorPreset(name: "Purple",  r: 128, g: 0,   b: 128),
    ColorPreset(name: "Teal",    r: 0,   g: 128, b: 128),
    ColorPreset(name: "White",   r: 255, g: 255, b: 255),
    ColorPreset(name: "Gray",    r: 128, g: 128, b: 128),
    ColorPreset(name: "Black",   r: 0,   g: 0,   b: 0),
]

struct ColorMixerView: View {
    @State private var red: Double = 128
    @State private var green: Double = 128
    @State private var blue: Double = 128
    @State private var showHex = true

    var body: some View {
        VStack(spacing: 8) {
            // Color swatch + value display
            HStack(spacing: 8) {
                Color(red: red / 255.0, green: green / 255.0, blue: blue / 255.0)
                    .frame(width: 40, height: 24)
                if showHex {
                    Text(String(format: "#%02X%02X%02X", Int(red), Int(green), Int(blue)))
                } else {
                    Text("R:\(Int(red)) G:\(Int(green)) B:\(Int(blue))")
                }
                Spacer()
                Toggle("Hex", isOn: $showHex)
            }
            .frame(height: 64)

            // RGB Sliders
            HStack {
                Text("R:\(Int(red))")
                    .frame(width: 50)
                Slider(value: $red, in: 0...255, step: 1)
            }
            HStack {
                Text("G:\(Int(green))")
                    .frame(width: 50)
                Slider(value: $green, in: 0...255, step: 1)
            }
            HStack {
                Text("B:\(Int(blue))")
                    .frame(width: 50)
                Slider(value: $blue, in: 0...255, step: 1)
            }

            Divider()

            // Preset colors — tap a row to apply
            List {
                ForEach(0..<presets.count) { i in
                    Text(presets[i].name)
                        .onTapGesture {
                            red = presets[i].r
                            green = presets[i].g
                            blue = presets[i].b
                        }
                }
            }
        }
        .padding()
    }
}

struct ColorMixerApp: App {
    var body: some Scene {
        WindowGroup("Color Mixer") {
            ColorMixerView()
        }
    }
}

#if os(macOS)
ColorMixerApp.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(ColorMixerApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ColorMixerApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ColorMixerApp.self)
#else
print("ColorMixer app defined. No backend available on this platform.")
#endif
