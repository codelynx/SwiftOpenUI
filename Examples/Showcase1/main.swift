import SwiftOpenUI

/// Showcase1: Basic views — Text, Button, Spacer, Divider, Color
struct Showcase1View: View {
    @State private var message = "Hello"

    var body: some View {
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

struct Showcase1App: App {
    var body: some Scene {
        WindowGroup("Showcase 1") {
            Showcase1View()
        }
    }
}

print("Showcase1 app defined. Needs a backend to run.")
