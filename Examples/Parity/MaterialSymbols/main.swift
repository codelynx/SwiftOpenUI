// Parity: MaterialSymbols — exercises Image(material: "name") on non-macOS.
//
// The bundled Material Symbols Rounded font (from the SwiftOpenUISymbols
// target) is loaded process-locally by each backend at startup. This
// example renders three named glyphs via Image(material:) to prove the
// full chain: font registration → Pango / DirectWrite / equivalent text
// shaping → OpenType ligature substitution → visible icon glyph.
//
// macOS builds intentionally do not bundle the Material Symbols font
// (SwiftUI uses native SF Symbols via Image(systemName:)). Running this
// example on macOS renders placeholders for each icon — that's the
// documented behavior; cross-platform code that needs true portability
// uses Image(systemName:) instead.

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

struct ParityMaterialSymbolsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Material Symbols parity")
                .font(.headline)

            Text("Icons render via Image(material: \"name\") on non-macOS,")
                .font(.caption)
            Text("using the bundled Material Symbols Rounded font.")
                .font(.caption)

            HStack(spacing: 32) {
                #if os(macOS)
                // macOS uses native SF Symbols — closest equivalents
                Image(systemName: "house")
                    .imageScale(.large)
                Image(systemName: "magnifyingglass")
                    .imageScale(.large)
                Image(systemName: "folder")
                    .imageScale(.large)
                #else
                Image(material: "home")
                    .imageScale(.large)
                Image(material: "search")
                    .imageScale(.large)
                Image(material: "folder_open")
                    .imageScale(.large)
                #endif
            }
            .padding()
        }
        .padding()
    }
}

struct ParityMaterialSymbolsApp: App {
    var body: some Scene {
        WindowGroup("Material Symbols Parity") {
            ParityMaterialSymbolsView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityMaterialSymbolsApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityMaterialSymbolsApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityMaterialSymbolsApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityMaterialSymbolsApp.self)
#else
print("ParityMaterialSymbols defined. No backend available on this platform.")
#endif
