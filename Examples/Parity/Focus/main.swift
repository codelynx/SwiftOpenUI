// Parity: Focus
// Owner: @FocusState, .focused()
// See: docs/architecture/swiftui-parity-matrix.md § State & Data + § Modifiers

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

// MARK: - Focus field enum

enum FocusField {
    case name
    case email
    case notes
}

struct ParityFocusView: View {
    // MARK: - @FocusState (Bool variant)
    @FocusState private var isNameFocused: Bool

    // MARK: - @FocusState (enum variant)
    @FocusState private var focusedField: FocusField?

    @State private var name = ""
    @State private var email = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parity: Focus")
                .font(.headline)
                .padding(.bottom, 4)

            // MARK: - @FocusState (Bool)

            VStack(alignment: .leading, spacing: 4) {
                Text("@FocusState (Bool)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                TextField("Name (Bool focus)", text: $name)
                    .focused($isNameFocused)
                Text("Focused: \(isNameFocused ? "YES" : "NO")")
                    .foregroundColor(isNameFocused ? .green : .gray)
                HStack(spacing: 8) {
                    Button("Focus") { isNameFocused = true }
                    Button("Unfocus") { isNameFocused = false }
                }
            }

            Divider()

            // MARK: - @FocusState (enum)

            VStack(alignment: .leading, spacing: 4) {
                Text("@FocusState (enum)")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                TextField("Name", text: $name)
                    .focused($focusedField, equals: .name)
                TextField("Email", text: $email)
                    .focused($focusedField, equals: .email)
                TextField("Notes", text: $notes)
                    .focused($focusedField, equals: .notes)

                HStack {
                    Text("Active:")
                    Text(focusLabel)
                        .foregroundColor(.blue)
                }

                HStack(spacing: 8) {
                    Button("Name") { focusedField = .name }
                    Button("Email") { focusedField = .email }
                    Button("Notes") { focusedField = .notes }
                    Button("Clear") { focusedField = nil }
                }
            }

            Spacer()
        }
        .padding()
    }

    private var focusLabel: String {
        switch focusedField {
        case .name: return "Name"
        case .email: return "Email"
        case .notes: return "Notes"
        case nil: return "None"
        }
    }
}

struct ParityFocusApp: App {
    var body: some Scene {
        WindowGroup("Parity: Focus") {
            ParityFocusView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(ParityFocusApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityFocusApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityFocusApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityFocusApp.self)
#else
print("ParityFocus defined. No backend available on this platform.")
#endif
