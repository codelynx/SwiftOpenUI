// Parity: Gestures
// Owner: .onTapGesture(), .onLongPressGesture(), .onDrag()
// See: docs/architecture/swiftui-parity-matrix.md § Modifiers

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

struct ParityGesturesView: View {
    @State private var tapCount = 0
    @State private var doubleTapCount = 0
    @State private var longPressCount = 0
    @State private var dragOffset: (x: Double, y: Double) = (0, 0)
    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parity: Gestures")
                .font(.headline)
                .padding(.bottom, 4)

            // MARK: - .onTapGesture()

            VStack(alignment: .leading, spacing: 4) {
                Text(".onTapGesture()")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                // Single tap
                Text("Tap me (\(tapCount))")
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .onTapGesture {
                        tapCount += 1
                    }

                // Double tap (count: 2)
                Text("Double-tap me (\(doubleTapCount))")
                    .padding(8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .onTapGesture(count: 2) {
                        doubleTapCount += 1
                    }
            }

            Divider()

            // MARK: - .onLongPressGesture()

            VStack(alignment: .leading, spacing: 4) {
                Text(".onLongPressGesture()")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Text("Long press me (\(longPressCount))")
                    .padding(8)
                    .background(longPressCount > 0 ? Color.orange : Color.red)
                    .foregroundColor(.white)
                    .onLongPressGesture {
                        longPressCount += 1
                    }

                Text("With 1s duration (\(longPressCount))")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
            }

            Divider()

            // MARK: - .onDrag()

            VStack(alignment: .leading, spacing: 4) {
                Text(".onDrag()")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                #if os(macOS)
                // macOS SwiftUI .onDrag is drag-and-drop, not gesture tracking.
                // SwiftOpenUI's .onDrag(minimumDistance:action:) is the gesture version.
                Text("(SwiftOpenUI gesture — not available on macOS SwiftUI)")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                #else
                Text(isDragging ? "Dragging..." : "Drag me")
                    .padding(8)
                    .background(isDragging ? Color.purple : Color(red: 0.3, green: 0.3, blue: 0.3))
                    .foregroundColor(.white)
                    .onDrag { offset in
                        isDragging = true
                        dragOffset = (offset.width, offset.height)
                    }

                Text(String(format: "Offset: (%.0f, %.0f)", dragOffset.x, dragOffset.y))
                    .font(.caption)
                    .foregroundColor(.gray)

                Button("Reset drag") {
                    isDragging = false
                    dragOffset = (0, 0)
                }
                #endif
            }

            Spacer()
        }
        .padding()
    }
}

struct ParityGesturesApp: App {
    var body: some Scene {
        WindowGroup("Parity: Gestures") {
            ParityGesturesView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityGesturesApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityGesturesApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityGesturesApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityGesturesApp.self)
#else
print("ParityGestures defined. No backend available on this platform.")
#endif
