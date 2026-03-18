#if canImport(SwiftUI) && os(macOS) && !SWIFTOPENUI_BACKEND
import SwiftUI
#else
import SwiftOpenUI
#endif

public struct ButtonsView: View {
    @State private var tapCount = 0
    @State private var lastAction = "None"

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Buttons")
                .font(.title)
            Divider()

            Group {
                Text("String Label")
                    .font(.headline)
                Button("Tap Me") {
                    tapCount += 1
                }
                Text("Tapped \(tapCount) times")
            }

            Divider()

            Group {
                Text("Custom Label")
                    .font(.headline)
                Button(action: { lastAction = "Custom button tapped" }) {
                    HStack(spacing: 4) {
                        Text("★")
                            .foregroundColor(.yellow)
                        Text("Star Button")
                    }
                }
                Text("Last action: \(lastAction)")
            }

            Divider()

            Group {
                Text("Multiple Buttons")
                    .font(.headline)
                HStack(spacing: 8) {
                    Button("Red") { lastAction = "Red" }
                    Button("Green") { lastAction = "Green" }
                    Button("Blue") { lastAction = "Blue" }
                }
            }

            Spacer()
        }
        .padding()
    }
}
