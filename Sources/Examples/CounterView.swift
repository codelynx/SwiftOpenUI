#if canImport(SwiftUI) && os(macOS) && !SWIFTOPENUI_BACKEND
import SwiftUI
#else
import SwiftOpenUI
#endif

public struct CounterView: View {
    @State private var count = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            Text("Count: \(count)")
            Button("Increment") { count += 1 }
        }
        .padding()
    }
}
