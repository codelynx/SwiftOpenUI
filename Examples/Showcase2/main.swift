import SwiftOpenUI

/// Showcase2: Layout — VStack, HStack, ZStack, ForEach
struct Showcase2View: View {
    let items = ["Red", "Green", "Blue"]

    var body: some View {
        VStack(spacing: 8) {
            Text("Showcase 2: Layout")
                .font(.title)
            Divider()
            HStack(spacing: 16) {
                ForEach(0..<3) { index in
                    Text("Item \(index)")
                        .padding(4)
                        .background(.gray)
                }
            }
            ZStack {
                Color.blue.opacity(0.2)
                Text("Centered on blue")
            }
            .frame(width: 200, height: 100)
        }
        .padding()
    }
}

struct Showcase2App: App {
    var body: some Scene {
        WindowGroup("Showcase 2") {
            Showcase2View()
        }
    }
}

print("Showcase2 app defined. Needs a backend to run.")
