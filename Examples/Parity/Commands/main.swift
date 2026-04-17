// Parity: Commands + FocusedValue
// Owner: Commands, @FocusedValue, .focusedValue(), CommandGroup, CommandMenuItem
// Proves: menu bar rendering, focus-based enable/disable,
//         observation-driven menu updates, keyboard shortcuts

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

// MARK: - Observable state

// MARK: - Observable state

#if os(macOS)
class CounterState: ObservableObject {
	@Published var count: Int = 0
	@Published var isBusy: Bool = false
}
#else
class CounterState: SwiftOpenUI.ObservableObject {
	@SwiftOpenUI.Published var count: Int = 0
	@SwiftOpenUI.Published var isBusy: Bool = false
}
#endif

// MARK: - FocusedValueKey

struct CounterFocusKey: FocusedValueKey {
	typealias Value = CounterState
}

extension FocusedValues {
	var counter: CounterState? {
		get { self[CounterFocusKey.self] }
		set { /* set by .focusedValue() modifier */ }
	}
}

// MARK: - Commands

#if !os(macOS)
struct CounterCommands: Commands {
	@FocusedValue(\.counter) var counter

	var body: some Commands {
		CommandGroup(replacing: .newItem) {
			CommandMenuItem("Increment", shortcut: KeyboardShortcut("i", modifiers: .command)) {
				counter?.count += 1
			}
			.disabled(counter == nil || counter!.isBusy)

			CommandMenuItem("Reset", shortcut: KeyboardShortcut("r", modifiers: .command)) {
				counter?.count = 0
			}
			.disabled(counter == nil)

			CommandMenuItem("Toggle Busy", shortcut: KeyboardShortcut("b", modifiers: .command)) {
				counter?.isBusy.toggle()
			}
			.disabled(counter == nil)
		}
	}
}
#endif

// MARK: - Views

struct MainContentView: View {
	#if os(macOS)
	@StateObject private var counter = CounterState()
	#else
	@SwiftOpenUI.StateObject private var counter = CounterState()
	#endif

	var body: some View {
		VStack(spacing: 16) {
			Text("Main Window")
				.font(.headline)
			Text("Count: \(counter.count)")
				.font(.title2)
			Text(counter.isBusy ? "Status: BUSY" : "Status: idle")

			HStack(spacing: 8) {
				Button("Increment") { counter.count += 1 }
				Button("Reset") { counter.count = 0 }
				Button(counter.isBusy ? "Set Idle" : "Set Busy") {
					counter.isBusy.toggle()
				}
			}

			Text("This window provides @FocusedValue.")
				.font(.caption)
			Text("Menu commands are enabled here.")
				.font(.caption)
		}
		.padding()
		#if os(macOS)
		.focusedValue(\.counter, counter)
		#else
		.focusedValue(CounterFocusKey.self, counter)
		#endif
	}
}

struct SecondaryContentView: View {
	var body: some View {
		VStack(spacing: 16) {
			Text("Secondary Window")
				.font(.headline)
			Text("No @FocusedValue here.")
			Text("Menu commands should be disabled.")
				.font(.caption)
		}
		.padding()
	}
}

// MARK: - App

struct ParityCommandsApp: App {
	var body: some Scene {
		#if os(macOS)
		WindowGroup("Commands Parity") {
			MainContentView()
		}
		#else
		WindowGroup("Commands Parity") {
			MainContentView()
		}
		.commands {
			CounterCommands()
		}

		Window("Secondary", id: "secondary") {
			SecondaryContentView()
		}
		#endif
	}
}

#if os(macOS)
MacAppLauncher.run(ParityCommandsApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityCommandsApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityCommandsApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityCommandsApp.self)
#else
print("ParityCommands defined. No backend available on this platform.")
#endif
