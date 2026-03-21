// Parity: App Structure
// Owner: App, Scene, WindowGroup, @SceneBuilder, @ViewBuilder,
//        window sizing / resize behavior
// See: docs/architecture/swiftui-parity-matrix.md § App Structure
//
// Note: Every parity example implicitly validates App, Scene, WindowGroup,
// @SceneBuilder, and @ViewBuilder by compiling and launching. This example
// makes it explicit and exercises WindowGroup(title:) and @ViewBuilder
// with multiple children (up to 12).

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

// MARK: - @ViewBuilder validation

struct ViewBuilderDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("@ViewBuilder")
                .font(.subheadline)
                .foregroundColor(.gray)

            // 2 children
            twoChildren

            // Conditional
            conditionalContent(flag: true)
            conditionalContent(flag: false)

            // Optional
            optionalContent(show: true)
            optionalContent(show: false)

            // Many children (exercises TupleView arity)
            manyChildren
        }
    }

    @ViewBuilder
    private var twoChildren: some View {
        Text("Child 1")
        Text("Child 2")
    }

    @ViewBuilder
    private func conditionalContent(flag: Bool) -> some View {
        if flag {
            Text("Condition: true")
                .foregroundColor(.green)
        } else {
            Text("Condition: false")
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private func optionalContent(show: Bool) -> some View {
        if show {
            Text("Optional: visible")
                .foregroundColor(.blue)
        }
    }

    @ViewBuilder
    private var manyChildren: some View {
        HStack(spacing: 4) {
            Text("1").frame(width: 20)
            Text("2").frame(width: 20)
            Text("3").frame(width: 20)
            Text("4").frame(width: 20)
            Text("5").frame(width: 20)
            Text("6").frame(width: 20)
        }
        .font(.caption)
        .foregroundColor(.orange)
    }
}

// MARK: - Root view

struct ParityAppStructureView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parity: App Structure")
                .font(.headline)
                .padding(.bottom, 4)

            // MARK: - App + Scene + WindowGroup

            VStack(alignment: .leading, spacing: 4) {
                Text("App + Scene + WindowGroup")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("This window validates:")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                Text("• App protocol (ParityAppStructureApp)")
                    .font(.caption)
                Text("• Scene protocol (body: some Scene)")
                    .font(.caption)
                Text("• WindowGroup(title:) with custom title")
                    .font(.caption)
                Text("• @SceneBuilder (single scene)")
                    .font(.caption)
            }

            Divider()

            // MARK: - @ViewBuilder

            ViewBuilderDemo()

            Spacer()
        }
        .padding()
    }
}

// MARK: - App (validates App protocol, Scene, WindowGroup, @SceneBuilder)

struct ParityAppStructureApp: App {
    var body: some Scene {
        WindowGroup("Parity: App Structure") {
            ParityAppStructureView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityAppStructureApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityAppStructureApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityAppStructureApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityAppStructureApp.self)
#else
print("ParityAppStructure defined. No backend available on this platform.")
#endif
