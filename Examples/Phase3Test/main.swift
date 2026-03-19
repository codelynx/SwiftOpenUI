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

struct Phase3TestView: View {
    @State private var isOn = false
    @State private var sliderValue = 0.5
    @State private var items = ["Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape"]

    var body: some View {
        VStack(spacing: 12) {
            Text("Phase 3 Views")
                .font(.largeTitle)

            Divider()

            // Toggle
            Toggle("Dark Mode", isOn: $isOn)
            Text(isOn ? "ON" : "OFF")

            Divider()

            // Slider
            Text("Slider: \(Int(sliderValue * 100))%")
            Slider(value: $sliderValue)

            Divider()

            // Image (GTK icon theme)
            #if !os(macOS)
            HStack(spacing: 16) {
                Image(systemName: "document-open")
                Image(systemName: "edit-copy").imageScale(.large)
                Image(systemName: "dialog-information").imageScale(.small)
            }
            #else
            HStack(spacing: 16) {
                Image(systemName: "doc")
                Image(systemName: "doc.on.doc")
                Image(systemName: "info.circle")
            }
            #endif

            Divider()

            // ScrollView + List
            Text("Fruits:")
            List {
                ForEach(items, id: \.self) { item in
                    Text(item)
                }
            }
        }
        .padding()
    }
}

struct Phase3TestApp: App {
    var body: some Scene {
        WindowGroup("Phase 3 Test") {
            Phase3TestView()
        }
    }
}

#if os(macOS)
Phase3TestApp.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(Phase3TestApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(Phase3TestApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(Phase3TestApp.self)
#else
print("Phase3Test app defined. No backend available on this platform.")
#endif
