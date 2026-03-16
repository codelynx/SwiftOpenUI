import SwiftOpenUI

struct CounterView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 8) {
            Text("Count: \(count)")
            Button("Increment") { count += 1 }
        }
    }
}

struct CounterApp: App {
    var body: some Scene {
        WindowGroup("Counter") {
            CounterView()
        }
    }
}

// TODO: Backend launch
print("Counter app defined. Needs a backend to run.")
