// Parity: CosmeticModifiers
// Owner: .controlSize(), .listStyle(.plain), .textFieldStyle(.plain),
//        .monospacedDigit(), .accessibilityIdentifier(), .textSelection()
// See: docs/issues/gtk4-win32-cosmetic-view-modifier-noops.md
//      docs/issues/gtk4-win32-textselection-modifier.md
//
// On macOS these render their native SwiftUI effect. On GTK4/Win32 the
// cosmetic ones are accepted no-ops (API parity) except .monospacedDigit
// (tabular figures) and .textSelection (selectable label) which have
// real backend behavior. The point of this example is that the SAME
// source compiles and runs everywhere with no #if os() guards.

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

struct ParityCosmeticModifiersView: View {
	#if os(macOS)
	@State private var fieldText = "plain style"
	#else
	@SwiftOpenUI.State private var fieldText = "plain style"
	#endif

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Parity: CosmeticModifiers")
				.font(.headline)

			// MARK: - .controlSize()

			VStack(alignment: .leading, spacing: 4) {
				Text(".controlSize()")
					.font(.subheadline)
					.foregroundColor(.gray)
				HStack(spacing: 8) {
					Button("mini") {}.controlSize(.mini)
					Button("small") {}.controlSize(.small)
					Button("regular") {}.controlSize(.regular)
					Button("large") {}.controlSize(.large)
				}
			}

			// MARK: - .textFieldStyle(.plain)

			VStack(alignment: .leading, spacing: 4) {
				Text(".textFieldStyle(.plain)")
					.font(.subheadline)
					.foregroundColor(.gray)
				TextField("Filter", text: $fieldText)
					.textFieldStyle(.plain)
			}

			// MARK: - .monospacedDigit()

			VStack(alignment: .leading, spacing: 4) {
				Text(".monospacedDigit() — digits below should align in columns")
					.font(.subheadline)
					.foregroundColor(.gray)
				Text("111,111.11")
					.monospacedDigit()
				Text("808,080.08")
					.monospacedDigit()
			}

			// MARK: - .textSelection(.enabled)

			VStack(alignment: .leading, spacing: 4) {
				Text(".textSelection(.enabled) — drag to select this path")
					.font(.subheadline)
					.foregroundColor(.gray)
				Text("/tmp/example/selectable/path.txt")
					.textSelection(.enabled)
			}

			// MARK: - .listStyle(.plain) + .accessibilityIdentifier()

			VStack(alignment: .leading, spacing: 4) {
				Text(".listStyle(.plain) — plain rows, no inset grouping")
					.font(.subheadline)
					.foregroundColor(.gray)
				List {
					Text("row one")
					Text("row two")
					Text("row three")
				}
				.listStyle(.plain)
				.accessibilityIdentifier("cosmetic-plain-list")
				.frame(height: 90)
			}

			Spacer()
		}
		.padding()
	}
}

struct ParityCosmeticModifiersApp: App {
	var body: some Scene {
		WindowGroup("Parity: CosmeticModifiers") {
			ParityCosmeticModifiersView()
		}
	}
}

#if os(macOS)
MacAppLauncher.run(ParityCosmeticModifiersApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityCosmeticModifiersApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityCosmeticModifiersApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityCosmeticModifiersApp.self)
#else
print("ParityCosmeticModifiers defined. No backend available on this platform.")
#endif
