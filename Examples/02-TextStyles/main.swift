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

// MARK: - Text Styles Demo

/// Demonstrates all Font presets, custom fonts, colors, and opacity.
struct TextStylesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Font presets
            Text("Large Title").font(.largeTitle)
            Text("Title").font(.title)
            Text("Title 2").font(.title2)
            Text("Title 3").font(.title3)
            Text("Headline").font(.headline)
            Text("Subheadline").font(.subheadline)
            Text("Body").font(.body)
            Text("Callout").font(.callout)
            Text("Footnote").font(.footnote)
            Text("Caption").font(.caption)
            Text("Caption 2").font(.caption2)
        }
        .padding()
    }
}

struct ColorTextView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Named Colors")
                .font(.headline)
            Text("Red text").foregroundColor(.red)
            Text("Blue text").foregroundColor(.blue)
            Text("Green text").foregroundColor(.green)
            Text("Orange text").foregroundColor(.orange)
            Text("Purple text").foregroundColor(.purple)
            Text("Pink text").foregroundColor(.pink)
            Text("Teal text").foregroundColor(.teal)
            Text("Indigo text").foregroundColor(.indigo)

            Divider()

            Text("Opacity")
                .font(.headline)
            HStack(spacing: 8) {
                Text("100%").foregroundColor(.blue)
                Text("75%").foregroundColor(.blue.opacity(0.75))
                Text("50%").foregroundColor(.blue.opacity(0.5))
                Text("25%").foregroundColor(.blue.opacity(0.25))
            }
        }
        .padding()
    }
}

struct TextStylesApp: App {
    var body: some Scene {
        WindowGroup("02 - Text Styles") {
            VStack(spacing: 8) {
                TextStylesView()
                Divider()
                ColorTextView()
            }
        }
    }
}

#if os(macOS)
TextStylesApp.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(TextStylesApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(TextStylesApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(TextStylesApp.self)
#else
print("TextStyles app defined. No backend available on this platform.")
#endif
