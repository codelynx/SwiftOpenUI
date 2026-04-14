// Parity: DropDestination
// Owner: .dropDestination(for:action:isTargeted:)
// Proves: file drag-and-drop from OS file manager, nested content drops,
//         isTargeted hover feedback (GTK4), drop acceptance/rejection.
//
// Win32 limitation: isTargeted is a no-op (WM_DROPFILES has no
// enter/leave notification). Hover highlight will not appear on Windows.
// Full OLE IDropTarget support would be needed for parity.

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

import Foundation

struct ParityDropDestinationView: View {
	#if os(macOS)
	@State private var droppedPaths: [String] = []
	@State private var isHovering = false
	@State private var lastResult = ""
	#else
	@SwiftOpenUI.State private var droppedPaths: [String] = []
	@SwiftOpenUI.State private var isHovering = false
	@SwiftOpenUI.State private var lastResult = ""
	#endif

	var body: some View {
		VStack(spacing: 16) {
			Text("Parity: DropDestination")
				.font(.headline)
			Text("Drag files or folders from your file manager onto the box below.")
				.font(.caption)

			// Drop zone with nested composed content
			VStack(spacing: 8) {
				Text(isHovering ? "Release to drop!" : "Drop files here")
					.font(.title2)
				Text(lastResult.isEmpty ? "(nothing dropped yet)" : lastResult)
					.font(.caption)
			}
			.frame(minWidth: 300, minHeight: 150)
			.padding()
			.background(Color.gray.opacity(0.1))
			.border(isHovering ? Color.green : Color.gray)
			.dropDestination(for: URL.self) { urls, location in
				let paths = urls.map { $0.path }
				droppedPaths = paths
				lastResult = "Dropped \(urls.count) item(s) at (\(Int(location.x)), \(Int(location.y)))"
				return true
			} isTargeted: { hovering in
				isHovering = hovering
			}

			Text("Dropped paths:")
				.font(.subheadline)
			ForEach(Array(droppedPaths.suffix(5).enumerated()), id: \.offset) { _, path in
				Text("  \(path)")
					.font(.caption)
			}
		}
		.padding()
	}
}

struct ParityDropDestinationApp: App {
	var body: some Scene {
		WindowGroup("Drop Destination Parity") {
			ParityDropDestinationView()
		}
	}
}

#if os(macOS)
MacAppLauncher.run(ParityDropDestinationApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(ParityDropDestinationApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ParityDropDestinationApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(ParityDropDestinationApp.self)
#else
print("ParityDropDestination defined. No backend available on this platform.")
#endif
