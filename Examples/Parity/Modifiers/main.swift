// Parity: Modifiers
// Owner: .padding(), .frame(), .foregroundColor(), .foregroundStyle(),
//        .background(), .font(), .border(), .opacity(), .offset(),
//        .scaleEffect(), .imageScale(), .modifier()
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

// MARK: - Custom ViewModifier

struct HighlightModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(4)
            .foregroundColor(.white)
            .background(Color.purple)
    }
}

struct ParityModifiersView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Parity: Modifiers")
                .font(.headline)
                .padding(.bottom, 4)

            // MARK: - .padding()

            VStack(alignment: .leading, spacing: 4) {
                Text(".padding()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    // Uniform
                    Text("8")
                        .padding(8)
                        .background(Color.blue)
                    // Edge-specific
                    Text("H16")
                        .padding(.horizontal, 16)
                        .background(Color.green)
                    // Per-edge
                    Text("Mixed")
                        .padding(.top, 2)
                        .padding(.bottom, 8)
                        .padding(.leading, 12)
                        .padding(.trailing, 4)
                        .background(Color.red)
                }
            }

            Divider()

            // MARK: - .frame()

            VStack(alignment: .leading, spacing: 4) {
                Text(".frame()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    // Fixed
                    Text("60×30")
                        .frame(width: 60, height: 30)
                        .background(Color.blue)
                    // Min/max
                    Text("Flex")
                        .frame(minWidth: 40, maxWidth: 100, minHeight: 20)
                        .background(Color.green)
                }
            }

            Divider()

            // MARK: - .foregroundColor()

            VStack(alignment: .leading, spacing: 4) {
                Text(".foregroundColor()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    Text("Red").foregroundColor(.red)
                    Text("Blue").foregroundColor(.blue)
                    Text("Custom").foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.0))
                }
            }

            Divider()

            // MARK: - .foregroundStyle()

            VStack(alignment: .leading, spacing: 4) {
                Text(".foregroundStyle()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Styled green")
                    .foregroundStyle(.green)
            }

            Divider()

            // MARK: - .background()

            VStack(alignment: .leading, spacing: 4) {
                Text(".background()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    Text("Yellow bg")
                        .padding(4)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                    Text("Custom bg")
                        .padding(4)
                        .background(Color(red: 0.2, green: 0.2, blue: 0.4))
                }
            }

            Divider()

            // MARK: - .font()

            VStack(alignment: .leading, spacing: 2) {
                Text(".font()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Large Title").font(.largeTitle)
                Text("Title").font(.title)
                Text("Headline").font(.headline)
                Text("Body").font(.body)
                Text("Caption").font(.caption)
                Text("Custom 14pt bold")
                    .font(.system(size: 14, weight: .bold))
            }

            Divider()

            // MARK: - .border()

            VStack(alignment: .leading, spacing: 4) {
                Text(".border()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    Text("Red border")
                        .padding(4)
                        .border(Color.red)
                    Text("Blue border")
                        .padding(4)
                        .border(Color.blue)
                }
            }

            Divider()

            // MARK: - .opacity()

            VStack(alignment: .leading, spacing: 4) {
                Text(".opacity()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 4) {
                    Text("100%").opacity(1.0)
                    Text("70%").opacity(0.7)
                    Text("40%").opacity(0.4)
                    Text("15%").opacity(0.15)
                }
            }

            Divider()

            // MARK: - .offset()

            VStack(alignment: .leading, spacing: 4) {
                Text(".offset()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 16) {
                    Text("Normal")
                    Text("Offset(10,5)")
                        .foregroundColor(.orange)
                        .offset(x: 10, y: 5)
                }
                .frame(height: 24)
            }

            Divider()

            // MARK: - .scaleEffect()

            VStack(alignment: .leading, spacing: 4) {
                Text(".scaleEffect()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 20) {
                    Text("1.0x").scaleEffect(1.0)
                    Text("1.5x").scaleEffect(1.5)
                    Text("0.7x").scaleEffect(0.7)
                }
                .frame(height: 24)
            }

            Divider()

            // MARK: - .modifier() (custom ViewModifier)

            VStack(alignment: .leading, spacing: 4) {
                Text(".modifier()")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Custom highlight modifier")
                    .modifier(HighlightModifier())
            }

            Spacer()
        }
        .padding()
    }
}

struct ParityModifiersApp: App {
    var body: some Scene {
        WindowGroup("Parity: Modifiers") {
            ParityModifiersView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityModifiersApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityModifiersApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityModifiersApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityModifiersApp.self)
#else
print("ParityModifiers defined. No backend available on this platform.")
#endif
