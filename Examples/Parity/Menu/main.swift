// Parity: Menu
// Owner: Menu (labeled, view-shaped content), .menuStyle(.borderlessButton)
// See: docs/issues/gtk4-win32-menu-menustyle.md
//
// Mirrors Synca's merge-resolution control: a labeled Menu whose title
// reflects the current selection and whose three actions rewrite it.
// GTK4 shows a popover (verified on real hardware); Win32 currently
// renders the label only (popup pending — the known Menu Win32
// regression); macOS is the native reference.

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

struct ParityMenuView: View {
	#if os(macOS)
	@State private var resolution = "use destination"
	@State private var log: [String] = []
	#else
	@SwiftOpenUI.State private var resolution = "use destination"
	@SwiftOpenUI.State private var log: [String] = []
	#endif

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Parity: Menu")
				.font(.headline)

			Text("A labeled Menu with 3 actions — the label reflects the current pick.")
				.font(.caption)

			// MARK: - Labeled Menu, 3 actions (Synca merge-resolution shape)

			HStack(spacing: 8) {
				Text("conflict1.txt")
				Menu(resolution) {
					Button("Use Source") { pick("use source") }
					Button("Use Destination") { pick("use destination") }
					Button("Keep Both") { pick("keep both") }
				}
				.menuStyle(.borderlessButton)
			}

			// MARK: - Default-styled Menu

			Menu("Actions") {
				Button("First") { log.append("First") }
				Button("Second") { log.append("Second") }
				Button("Third") { log.append("Third") }
			}

			Text("Log:")
				.font(.subheadline)
			ForEach(Array(log.suffix(6).enumerated()), id: \.offset) { _, entry in
				Text("  \(entry)")
			}

			Spacer()
		}
		.padding()
	}

	private func pick(_ value: String) {
		resolution = value
		log.append("picked: \(value)")
	}
}

struct ParityMenuApp: App {
	var body: some Scene {
		WindowGroup("Parity: Menu") {
			ParityMenuView()
		}
	}
}

#if os(macOS)
MacAppLauncher.run(ParityMenuApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityMenuApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityMenuApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityMenuApp.self)
#else
print("ParityMenu defined. No backend available on this platform.")
#endif
