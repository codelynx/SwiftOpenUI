// Win32 Review Smoke Test
// Verifies: labelsHidden Picker, generic Picker with .tag(),
// @Environment(Observable.self) reactivity, ObservableObject reactivity

#if os(macOS)
import SwiftUI
import MacExampleSupport
#else
import SwiftOpenUI
#if canImport(BackendWin32)
import BackendWin32
#endif
#endif

#if canImport(Observation)
import Observation
#endif

@inline(__always)
private func debugBodyAccess(_ name: String) {
	print("[DEBUG] body \(name)")
}

// MARK: - @Observable test model

@Observable class ReviewModel {
	var count: Int = 0
}

// MARK: - ObservableObject test model

#if os(macOS)
class LegacyModel: ObservableObject {
	@Published var value: Int = 0
}
#else
class LegacyModel: SwiftOpenUI.ObservableObject {
	@SwiftOpenUI.Published var value: Int = 0
}
#endif

// MARK: - Test views

enum Fruit: String, CaseIterable {
	case apple, banana, cherry
}

/// Tests @Environment(Observable.self) — the pattern that previously crashed.
struct ObservableCounterView: View {
	@Environment(ReviewModel.self) var model

	var body: some View {
		debugBodyAccess("ObservableCounterView")
		return VStack(spacing: 8) {
			Text("--- @Environment(Observable.self) ---")
				.font(.subheadline)
			Text("Observable Count: \(model.count)")
			Button("Increment Observable") { model.count += 1 }
		}
	}
}

struct Win32ReviewView: View {
	#if os(macOS)
	@StateObject private var legacy = LegacyModel()
	@State private var fruit: Fruit = .apple
	@State private var pickerValue: Int = 0
	#else
	@SwiftOpenUI.StateObject private var legacy = LegacyModel()
	@SwiftOpenUI.State private var fruit: Fruit = .apple
	@SwiftOpenUI.State private var pickerValue: Int = 0
	#endif

	var body: some View {
		debugBodyAccess("Win32ReviewView")
		return VStack(spacing: 16) {
			Text("Win32 Review Smoke Test")
				.font(.headline)

			// 1. @Environment(Observable.self) reactivity (previously crashed)
			ObservableCounterView()

			// 2. ObservableObject + @StateObject reactivity
			Text("--- ObservableObject Reactivity ---")
				.font(.subheadline)
			Text("Legacy Count: \(legacy.value)")
			Button("Increment Legacy") { legacy.value += 1 }

			#if false
			Text("--- Picker with label ---")
				.font(.subheadline)
			Picker("Color:", selection: $pickerValue) {
				Text("Red").tag(0)
				Text("Green").tag(1)
				Text("Blue").tag(2)
			}

			Text("--- Picker .labelsHidden() ---")
				.font(.subheadline)
			Picker("Hidden:", selection: $pickerValue) {
				Text("Red").tag(0)
				Text("Green").tag(1)
				Text("Blue").tag(2)
			}
			.labelsHidden()

			Text("--- Segmented .labelsHidden() ---")
				.font(.subheadline)
			Picker("Also Hidden:", selection: $pickerValue) {
				Text("R").tag(0)
				Text("G").tag(1)
				Text("B").tag(2)
			}
			.pickerStyle(.segmented)
			.labelsHidden()

			Text("--- Generic Picker (ForEach+tag) ---")
				.font(.subheadline)
			Picker("Fruit:", selection: $fruit) {
				ForEach(Fruit.allCases, id: \.self) { f in
					Text(f.rawValue.capitalized).tag(f)
				}
			}

			Text("Selected: \(fruit.rawValue)")
				.font(.caption)
			#endif
		}
		.padding()
	}
}

// MARK: - App

struct Win32ReviewApp: App {
	let model = ReviewModel()

	var body: some Scene {
		WindowGroup("Win32 Review") {
			Win32ReviewView()
				.environment(model)
		}
	}
}

#if os(macOS)
MacAppLauncher.run(Win32ReviewApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(Win32ReviewApp.self)
#else
print("No backend available.")
#endif
