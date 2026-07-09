// Parity: KeyboardShortcut
// Owner: .keyboardShortcut(), .onExitCommand(), hidden window-scoped shortcut
// See: docs/architecture/swiftui-parity-matrix.md § Modifiers
//      docs/issues/gtk4-onexitcommand-esc-handling.md
//      docs/issues/gtk4-hidden-keyboardshortcut-button.md

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

// MARK: - Keyboard Shortcut Demo

struct ParityKeyboardShortcutView: View {
	#if os(macOS)
	@State private var log: [String] = []
	@State private var filterText = ""
	@FocusState private var filterFocused: Bool
	#else
	@SwiftOpenUI.State private var log: [String] = []
	@SwiftOpenUI.State private var filterText = ""
	@SwiftOpenUI.FocusState private var filterFocused: Bool
	#endif

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Parity: KeyboardShortcut")
				.font(.headline)

			Text("Press Ctrl+O, Ctrl+S, Ctrl+Shift+N, or Return")
				.font(.caption)

			HStack(spacing: 8) {
				Button("Open (⌘O)") { log.append("Open") }
					.keyboardShortcut("o", modifiers: .command)

				Button("Save (⌘S)") { log.append("Save") }
					.keyboardShortcut("s", modifiers: .command)

				Button("New (⌘⇧N)") { log.append("New") }
					.keyboardShortcut("n", modifiers: [.command, .shift])

				Button("OK") { log.append("OK (Return)") }
					.keyboardShortcut(.defaultAction)
			}

			// MARK: - .onExitCommand + hidden window-scoped shortcut
			//
			// ESC inside the field clears + defocuses (.onExitCommand).
			// ⌘F focuses the field via a shortcut with NO visible control —
			// a hidden Button, mirroring Synca's filter-field pattern.
			VStack(alignment: .leading, spacing: 4) {
				Text("⌘F focuses (no visible control) · ESC clears + defocuses")
					.font(.caption)
				TextField("Filter", text: $filterText)
					.focused($filterFocused)
					.onSubmit { log.append("submit: \(filterText)") }
					.onExitCommand {
						filterText = ""
						filterFocused = false
						log.append("ESC: cleared + defocused")
					}
			}

			Button("Find") {
				filterFocused = true
				log.append("⌘F: focus filter")
			}
			.keyboardShortcut("f", modifiers: .command)
			.hidden()

			Text("Log:")
				.font(.subheadline)
			ForEach(Array(log.suffix(8).enumerated()), id: \.offset) { _, entry in
				Text("  \(entry)")
			}
		}
		.padding()
	}
}

// MARK: - App

struct ParityKeyboardShortcutApp: App {
	var body: some Scene {
		WindowGroup("Keyboard Shortcut Parity") {
			ParityKeyboardShortcutView()
		}
	}
}

#if os(macOS)
MacAppLauncher.run(ParityKeyboardShortcutApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityKeyboardShortcutApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityKeyboardShortcutApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityKeyboardShortcutApp.self)
#else
print("ParityKeyboardShortcut defined. No backend available on this platform.")
#endif
