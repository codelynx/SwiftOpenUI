// Parity: Views — Basic
// Owner: Text, Button, TextField, Color, Spacer, Divider
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

struct ParityViewsBasicView: View {
    // All @State on root for Android compatibility
    @State private var buttonCount = 0
    @State private var textFieldValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parity: Views — Basic")
                .font(.headline)
                .padding(.bottom, 4)

            // MARK: - Text

            VStack(alignment: .leading, spacing: 4) {
                Text("Text")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Plain text")
                Text("Bold text")
                    .font(.system(size: 16, weight: .bold))
                Text("Colored text")
                    .foregroundColor(.blue)
                Text("Large title style")
                    .font(.largeTitle)
                Text("Caption style")
                    .font(.caption)
            }

            Divider()

            // MARK: - Button

            VStack(alignment: .leading, spacing: 4) {
                Text("Button")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                // String label
                Button("String label (\(buttonCount))") {
                    buttonCount += 1
                }

                // Custom label (generic Label view)
                Button(action: { buttonCount += 1 }) {
                    HStack(spacing: 4) {
                        Text("Custom label")
                            .foregroundColor(.white)
                        Text("→")
                            .foregroundColor(.green)
                    }
                }

                // Button driving conditional
                Text(buttonCount > 0 ? "Tapped \(buttonCount) time(s)" : "Not tapped yet")
                    .foregroundColor(buttonCount > 0 ? .green : .red)
            }

            Divider()

            // MARK: - TextField

            VStack(alignment: .leading, spacing: 4) {
                Text("TextField")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                TextField("Type here...", text: $textFieldValue)
                Text("Echo: \(textFieldValue)")
                    .foregroundColor(.blue)
            }

            Divider()

            // MARK: - Color

            VStack(alignment: .leading, spacing: 4) {
                Text("Color")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 4) {
                    Color.red.frame(width: 24, height: 24)
                    Color.green.frame(width: 24, height: 24)
                    Color.blue.frame(width: 24, height: 24)
                    Color.yellow.frame(width: 24, height: 24)
                    Color.orange.frame(width: 24, height: 24)
                    Color.purple.frame(width: 24, height: 24)
                }
                HStack(spacing: 4) {
                    // Custom RGB
                    Color(red: 0.2, green: 0.6, blue: 0.9)
                        .frame(width: 24, height: 24)
                    // Opacity
                    Color.red.opacity(0.3)
                        .frame(width: 24, height: 24)
                    Color.red.opacity(0.6)
                        .frame(width: 24, height: 24)
                    Color.red.opacity(1.0)
                        .frame(width: 24, height: 24)
                }
            }

            Divider()

            // MARK: - Spacer

            VStack(alignment: .leading, spacing: 4) {
                Text("Spacer")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack {
                    Text("Left")
                    Spacer()
                    Text("Right")
                }
                .frame(height: 24)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
            }

            // MARK: - Divider

            VStack(alignment: .leading, spacing: 4) {
                Text("Divider")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Above divider")
                Divider()
                Text("Below divider")
            }

            Spacer()
        }
        .padding()
    }
}

struct ParityViewsBasicApp: App {
    var body: some Scene {
        WindowGroup("Parity: Views Basic") {
            ParityViewsBasicView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityViewsBasicApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityViewsBasicApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityViewsBasicApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityViewsBasicApp.self)
#else
print("ParityViewsBasic defined. No backend available on this platform.")
#endif
