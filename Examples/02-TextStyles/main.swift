import SwiftOpenUI
import ExamplesShared
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif

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

#if canImport(BackendGTK4)
GTK4Backend().run(TextStylesApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(TextStylesApp.self)
#elseif os(macOS)
print("TextStyles: Use apple/Examples.xcodeproj on macOS, or run on Linux/Windows.")
#else
print("TextStyles: No backend available on this platform.")
#endif
