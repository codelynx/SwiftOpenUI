// Parity: Animation
// Owner: .animation(), withAnimation()
// Cross-cutting: exercises .opacity(), .scaleEffect(), .offset() in animated context
//                (those rows are owned by ParityModifiers)
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

struct ParityAnimationView: View {
    @State private var animateOpacity = false
    @State private var animateScale = false
    @State private var animateOffset = false
    @State private var withAnimationFlag = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parity: Animation")
                .font(.headline)
                .padding(.bottom, 4)

            // MARK: - .animation() with opacity

            VStack(alignment: .leading, spacing: 4) {
                Text(".animation() + opacity")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 12) {
                    Text("Fade")
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .opacity(animateOpacity ? 0.2 : 1.0)
                        .animation(.easeInOut, value: animateOpacity)
                    Button("Toggle") { animateOpacity.toggle() }
                }
            }

            Divider()

            // MARK: - .animation() with scaleEffect

            VStack(alignment: .leading, spacing: 4) {
                Text(".animation() + scaleEffect")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 12) {
                    Text("Scale")
                        .padding(8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .scaleEffect(animateScale ? 1.5 : 1.0)
                        .animation(.easeInOut, value: animateScale)
                    Button("Toggle") { animateScale.toggle() }
                }
                .frame(height: 30)
            }

            Divider()

            // MARK: - .animation() with offset

            VStack(alignment: .leading, spacing: 4) {
                Text(".animation() + offset")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 12) {
                    Text("Slide")
                        .padding(8)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .offset(x: animateOffset ? 60 : 0, y: 0)
                        .animation(.easeInOut, value: animateOffset)
                    Spacer()
                    Button("Toggle") { animateOffset.toggle() }
                }
                .frame(height: 30)
            }

            Divider()

            // MARK: - withAnimation()

            VStack(alignment: .leading, spacing: 4) {
                Text("withAnimation()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 12) {
                    Text("Animated")
                        .padding(8)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .opacity(withAnimationFlag ? 0.3 : 1.0)
                        .scaleEffect(withAnimationFlag ? 0.8 : 1.0)
                        .offset(x: withAnimationFlag ? 30 : 0, y: 0)
                    Spacer()
                    Button("withAnimation") {
                        withAnimation(.easeInOut) {
                            withAnimationFlag.toggle()
                        }
                    }
                }
                .frame(height: 30)
            }

            Spacer()
        }
        .padding()
    }
}

struct ParityAnimationApp: App {
    var body: some Scene {
        WindowGroup("Parity: Animation") {
            ParityAnimationView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityAnimationApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityAnimationApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityAnimationApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityAnimationApp.self)
#else
print("ParityAnimation defined. No backend available on this platform.")
#endif
