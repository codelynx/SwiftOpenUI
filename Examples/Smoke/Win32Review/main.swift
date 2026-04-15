// Win32 Review Smoke Test
// Verifies: labelsHidden Picker, generic Picker with .tag(),
// @Environment(Observable.self) reactivity

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

// MARK: - ObservableObject test model

#if os(macOS)
class ReviewModel: ObservableObject {
	@Published var count: Int = 0
}
#else
class ReviewModel: SwiftOpenUI.ObservableObject {
	@SwiftOpenUI.Published var count: Int = 0
}
#endif

// MARK: - Test view

enum Fruit: String, CaseIterable {
	case apple, banana, cherry
}

struct Win32ReviewView: View {
	#if os(macOS)
	@StateObject private var model = ReviewModel()
	@State private var fruit: Fruit = .apple
	@State private var pickerValue: Int = 0
	#else
	@SwiftOpenUI.StateObject private var model = ReviewModel()
	@SwiftOpenUI.State private var fruit: Fruit = .apple
	@SwiftOpenUI.State private var pickerValue: Int = 0
	#endif

	var body: some View {
		VStack(spacing: 16) {
			Text("Win32 Review Smoke Test")
				.font(.headline)

			// 1. ObservableObject reactivity
			Text("--- ObservableObject Reactivity ---")
				.font(.subheadline)
			Text("Count: \(model.count)")
			Button("Increment") { model.count += 1 }

			// 2. Picker with label (should show "Color:" prefix)
			Text("--- Picker with label ---")
				.font(.subheadline)
			Picker("Color:", selection: $pickerValue) {
				Text("Red").tag(0)
				Text("Green").tag(1)
				Text("Blue").tag(2)
			}

			// 3. Picker with .labelsHidden() (should hide "Hidden:" prefix)
			Text("--- Picker .labelsHidden() ---")
				.font(.subheadline)
			Picker("Hidden:", selection: $pickerValue) {
				Text("Red").tag(0)
				Text("Green").tag(1)
				Text("Blue").tag(2)
			}
			.labelsHidden()

			// 4. Segmented Picker with .labelsHidden()
			Text("--- Segmented .labelsHidden() ---")
				.font(.subheadline)
			Picker("Also Hidden:", selection: $pickerValue) {
				Text("R").tag(0)
				Text("G").tag(1)
				Text("B").tag(2)
			}
			.pickerStyle(.segmented)
			.labelsHidden()

			// 5. Generic Picker with ForEach + .tag()
			Text("--- Generic Picker (ForEach+tag) ---")
				.font(.subheadline)
			Picker("Fruit:", selection: $fruit) {
				ForEach(Fruit.allCases, id: \.self) { f in
					Text(f.rawValue.capitalized).tag(f)
				}
			}

			Text("Selected: \(fruit.rawValue)")
				.font(.caption)
		}
		.padding()
	}
}

// MARK: - App

struct Win32ReviewApp: App {
	var body: some Scene {
		WindowGroup("Win32 Review") {
			Win32ReviewView()
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
