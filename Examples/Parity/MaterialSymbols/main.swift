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

            // Row 1: Image(material:) — direct Material names (non-macOS
            // only; macOS placeholder since no font is bundled there).
            // Exercises M-Symbols-2.
            Text("Row 1 — Image(material: \"name\")")
                .font(.caption)
            HStack(spacing: 32) {
                #if os(macOS)
                Text("(material: not available on macOS)")
                    .foregroundColor(.secondary)
                #else
                Image(material: "home")
                    .imageScale(.large)
                Image(material: "search")
                    .imageScale(.large)
                Image(material: "folder_open")
                    .imageScale(.large)
                #endif
            }

            // Row 2: Image(systemName:) — SwiftUI-canonical SF names.
            // On macOS: native SF Symbols. On non-macOS: routed through
            // SFSymbolCompatibility.map → Material glyph. Exercises
            // M-Symbols-3. Same source, runs everywhere.
            Text("Row 2 — Image(systemName: \"name\") via SF→Material map")
                .font(.caption)
            HStack(spacing: 32) {
                Image(systemName: "house")
                    .imageScale(.large)
                Image(systemName: "magnifyingglass")
                    .imageScale(.large)
                Image(systemName: "folder")
                    .imageScale(.large)
            }

            // Row 3: unmapped SF name → missing-icon placeholder glyph.
            // Exercises the M-Symbols-3 fallback path.
            Text("Row 3 — Unmapped SF name (placeholder expected)")
                .font(.caption)
            HStack(spacing: 32) {
                Image(systemName: "definitely.not.a.real.sf.symbol")
                    .imageScale(.large)
            }

            // Row 4: bitmap resource loaded via `Image(resource:)` — resolves
            // through `AppBundle.main` to find `Resources/Sample1.jpg` at the
            // package root in dev mode, or the platform-native bundle path in
            // packaged `.app` bundles. `.resizable().frame(...)` matches
            // SwiftUI semantics: without `.resizable()`, the frame positions
            // but does not scale the image; with it, the image stretches to
            // fill the frame.
            Text("Row 4 — Image(resource:).resizable().frame(...) bitmap from Resources/")
                .font(.caption)
            #if os(macOS)
            Text("(resource: not available on macOS)")
                .foregroundColor(.secondary)
            #else
            Image(resource: "Sample1.jpg")
                .resizable()
                .frame(width: 240, height: 180)
            #endif
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
