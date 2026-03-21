// Parity: Views — Layout
// Owner: VStack, HStack, ZStack, Group, ForEach, AnyView, EmptyView,
//        Alignment, Edge/Edge.Set, EdgeInsets, ProposedViewSize
// See: docs/architecture/swiftui-parity-matrix.md § Views + § Layout System

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

struct ParityViewsLayoutView: View {
    @State private var showOptional = true
    @State private var forEachCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parity: Views — Layout")
                .font(.headline)
                .padding(.bottom, 4)

            // MARK: - VStack

            VStack(alignment: .leading, spacing: 4) {
                Text("VStack")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    // Leading alignment
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Leading")
                            .font(.caption)
                        Text("A").background(Color.blue)
                        Text("BB").background(Color.blue)
                        Text("CCC").background(Color.blue)
                    }
                    .frame(width: 60)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))

                    // Center alignment
                    VStack(spacing: 2) {
                        Text("Center")
                            .font(.caption)
                        Text("A").background(Color.green)
                        Text("BB").background(Color.green)
                        Text("CCC").background(Color.green)
                    }
                    .frame(width: 60)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))

                    // Trailing alignment
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Trailing")
                            .font(.caption)
                        Text("A").background(Color.red)
                        Text("BB").background(Color.red)
                        Text("CCC").background(Color.red)
                    }
                    .frame(width: 60)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                }
            }

            Divider()

            // MARK: - HStack

            VStack(alignment: .leading, spacing: 4) {
                Text("HStack")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    Text("A")
                        .padding(4)
                        .background(Color.blue)
                    Text("B")
                        .padding(4)
                        .background(Color.green)
                    Text("C")
                        .padding(4)
                        .background(Color.red)
                }
                // Custom spacing
                HStack(spacing: 20) {
                    Text("Wide")
                    Text("Spacing")
                }
                .foregroundColor(.orange)
            }

            Divider()

            // MARK: - ZStack

            VStack(alignment: .leading, spacing: 4) {
                Text("ZStack")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                ZStack {
                    Color.blue.frame(width: 80, height: 40)
                    Color.green.frame(width: 60, height: 30)
                    Text("Top")
                        .foregroundColor(.white)
                }
                .frame(height: 40)
            }

            Divider()

            // MARK: - Group

            VStack(alignment: .leading, spacing: 4) {
                Text("Group")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Group {
                    Text("Item 1 (in Group)")
                    Text("Item 2 (in Group)")
                    Text("Item 3 (in Group)")
                }
                .foregroundColor(.cyan)
            }

            Divider()

            // MARK: - ForEach

            VStack(alignment: .leading, spacing: 4) {
                Text("ForEach")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                // Range-based with id for dynamic updates
                HStack(spacing: 4) {
                    ForEach(0..<forEachCount, id: \.self) { i in
                        Text("\(i)")
                            .frame(width: 24, height: 24)
                            .background(Color.purple)
                            .foregroundColor(.white)
                    }
                }
                HStack(spacing: 8) {
                    Button("-") { if forEachCount > 0 { forEachCount -= 1 } }
                    Button("+") { if forEachCount < 6 { forEachCount += 1 } }
                    Text("\(forEachCount) items")
                        .foregroundColor(.gray)
                }
            }

            Divider()

            // MARK: - AnyView

            VStack(alignment: .leading, spacing: 4) {
                Text("AnyView")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                makeAnyView(flag: showOptional)
            }

            Divider()

            // MARK: - EmptyView

            VStack(alignment: .leading, spacing: 4) {
                Text("EmptyView")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack {
                    Text("Before")
                    EmptyView()
                    Text("After (EmptyView between)")
                }
            }

            Spacer()
        }
        .padding()
    }

    private func makeAnyView(flag: Bool) -> AnyView {
        if flag {
            return AnyView(
                Text("AnyView wrapping Text")
                    .foregroundColor(.green)
            )
        } else {
            return AnyView(
                HStack {
                    Text("AnyView wrapping HStack")
                        .foregroundColor(.orange)
                }
            )
        }
    }
}

struct ParityViewsLayoutApp: App {
    var body: some Scene {
        WindowGroup("Parity: Views Layout") {
            ParityViewsLayoutView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityViewsLayoutApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityViewsLayoutApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityViewsLayoutApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityViewsLayoutApp.self)
#else
print("ParityViewsLayout defined. No backend available on this platform.")
#endif
