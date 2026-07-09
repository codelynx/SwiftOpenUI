// Parity: Accessibility
// Owner: .accessibilityLabel(), .accessibilityIdentifier()
// See: docs/issues/gtk4-win32-accessibilitylabel.md
//
// Verification is screen-reader-driven, not visual:
//   macOS — VoiceOver (⌘F5) should announce "Modified", "Delete", and
//           "Copy to destination" on the three icon-only controls, not
//           the SF Symbol names.
//   GTK4  — Orca should announce the same labels (verified on real
//           hardware by the Linux-side agent).
//   Win32 — Narrator, once the Win32 a11y bridge lands.

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

struct ParityAccessibilityView: View {
	#if os(macOS)
	@State private var log: [String] = []
	#else
	@SwiftOpenUI.State private var log: [String] = []
	#endif

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Parity: Accessibility")
				.font(.headline)

			Text("Icon-only controls below carry .accessibilityLabel — a screen reader should announce the label, not the icon name.")
				.font(.caption)

			// MARK: - .accessibilityLabel on icon-only elements
			// Mirrors Synca's action badges: an image whose meaning is
			// invisible to a screen reader without an explicit label.

			HStack(spacing: 16) {
				Image(systemName: "pencil.circle.fill")
					.accessibilityLabel("Modified")

				Button {
					log.append("delete tapped")
				} label: {
					Image(systemName: "trash")
				}
				.accessibilityLabel("Delete")

				Button {
					log.append("copy tapped")
				} label: {
					Image(systemName: "arrow.forward.circle")
				}
				.accessibilityLabel("Copy to destination")
			}

			// MARK: - .accessibilityIdentifier for UI automation

			Text("This row has .accessibilityIdentifier(\"a11y-status-row\") for test automation — invisible to users and screen readers.")
				.font(.caption)
				.accessibilityIdentifier("a11y-status-row")

			Text("Log:")
				.font(.subheadline)
			ForEach(Array(log.suffix(4).enumerated()), id: \.offset) { _, entry in
				Text("  \(entry)")
			}

			Spacer()
		}
		.padding()
	}
}

struct ParityAccessibilityApp: App {
	var body: some Scene {
		WindowGroup("Parity: Accessibility") {
			ParityAccessibilityView()
		}
	}
}

#if os(macOS)
MacAppLauncher.run(ParityAccessibilityApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityAccessibilityApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityAccessibilityApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityAccessibilityApp.self)
#else
print("ParityAccessibility defined. No backend available on this platform.")
#endif
