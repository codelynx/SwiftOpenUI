import SwiftOpenUI

public struct Showcase1View: View {
    @State private var message = "Hello"

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            Text("Showcase 1: Basic Views")
                .font(.title)
            Divider()
            Text(message)
                .foregroundColor(.blue)
            Button("Change Message") {
                message = message == "Hello" ? "World" : "Hello"
            }
            Spacer()
        }
        .padding()
    }
}
