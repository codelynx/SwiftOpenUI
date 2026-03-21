// Parity: Navigation
// Owner: NavigationStack, NavigationLink, NavigationPath,
//        .navigationTitle(), .navigationDestination(), NavigateAction
// See: docs/architecture/swiftui-parity-matrix.md § Navigation

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

// MARK: - Detail views (pure)

struct DetailView: View {
    let item: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Detail: \(item)")
                .font(.title)
            Text("Pushed via NavigationLink")
                .foregroundColor(.gray)
        }
        .navigationTitle(item)
        .padding()
    }
}

struct NumberDetailView: View {
    let number: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Number: \(number)")
                .font(.largeTitle)
                .foregroundColor(.blue)
            Text("Pushed via .navigationDestination(for: Int.self)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .navigationTitle("Number \(number)")
        .padding()
    }
}

// MARK: - Root view

struct ParityNavigationView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Parity: Navigation")
                    .font(.headline)
                    .padding(.bottom, 4)

                // MARK: - NavigationLink

                VStack(alignment: .leading, spacing: 4) {
                    Text("NavigationLink")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    NavigationLink("Go to Alpha", value: "Alpha")
                    NavigationLink("Go to Beta", value: "Beta")
                }

                Divider()

                // MARK: - NavigationPath (programmatic)

                VStack(alignment: .leading, spacing: 4) {
                    Text("NavigationPath (programmatic)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Path depth: \(path.count)")
                    HStack(spacing: 8) {
                        Button("Push 42") { path.append(42) }
                        Button("Push 99") { path.append(99) }
                    }
                    if path.count > 0 {
                        HStack(spacing: 8) {
                            Button("Pop") { path.removeLast() }
                            Button("Pop to root") {
                                path.removeLast(path.count)
                            }
                        }
                    }
                }

                Divider()

                // MARK: - NavigateAction (@Environment)

                VStack(alignment: .leading, spacing: 4) {
                    Text("NavigateAction")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("(Available inside pushed destinations)")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Navigation")
            // MARK: - .navigationDestination()
            .navigationDestination(for: String.self) { value in
                DetailView(item: value)
            }
            .navigationDestination(for: Int.self) { value in
                NumberDetailView(number: value)
            }
        }
    }
}

struct ParityNavigationApp: App {
    var body: some Scene {
        WindowGroup("Parity: Navigation") {
            ParityNavigationView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityNavigationApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityNavigationApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityNavigationApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityNavigationApp.self)
#else
print("ParityNavigation defined. No backend available on this platform.")
#endif
