#if canImport(SwiftUI) && os(macOS) && !SWIFTOPENUI_BACKEND
import SwiftUI
#else
import SwiftOpenUI
#endif

public struct FocusTestView: View {
    @State private var name = ""
    @State private var counter = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            Text("Type in the field, then click the button.")
                .font(.headline)
            Text("Cursor should stay in place after rebuild.")
            Divider()
            TextField("Type here...", text: $name)
            Text("You typed: \(name)")
            Text("Counter: \(counter)")
            Button("Increment (triggers rebuild)") { counter += 1 }
        }
        .padding()
    }
}
