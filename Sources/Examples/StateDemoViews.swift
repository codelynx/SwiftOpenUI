#if canImport(SwiftUI) && os(macOS) && !SWIFTOPENUI_BACKEND
import SwiftUI
#else
import SwiftOpenUI
#endif

public struct CounterSection: View {
    @State private var count = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("Counter")
                .font(.headline)
            Text("Count: \(count)")
            HStack(spacing: 8) {
                Button("−") { count -= 1 }
                Button("+") { count += 1 }
                Button("Reset") { count = 0 }
            }
        }
    }
}

public struct TextToggleSection: View {
    @State private var message = "Hello"

    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("Text Toggle")
                .font(.headline)
            Text(message)
                .foregroundColor(.blue)
            Button("Toggle") {
                message = message == "Hello" ? "World" : "Hello"
            }
        }
    }
}

public struct ConditionalSection: View {
    @State private var showDetail = false

    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("Conditional Rendering")
                .font(.headline)
            Button(showDetail ? "Hide Detail" : "Show Detail") {
                showDetail = !showDetail
            }
            if showDetail {
                Text("Here is the detail!")
                    .foregroundColor(.green)
                    .padding(4)
                    .background(.green.opacity(0.1))
            }
        }
    }
}

public struct BindingChild: View {
    @Binding var value: Int

    public init(value: Binding<Int>) {
        _value = value
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text("Child sees: \(value)")
            Button("Child +1") { value += 1 }
        }
    }
}

public struct BindingSection: View {
    @State private var shared = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("@Binding (Parent ↔ Child)")
                .font(.headline)
            Text("Parent value: \(shared)")
            Button("Parent +1") { shared += 1 }
            BindingChild(value: $shared)
                .padding(4)
                .border(.gray)
        }
    }
}

public struct MultiStateSection: View {
    @State private var a = 0
    @State private var b = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("Multiple @State")
                .font(.headline)
            HStack(spacing: 16) {
                VStack {
                    Text("A: \(a)")
                    Button("A+") { a += 1 }
                }
                VStack {
                    Text("B: \(b)")
                    Button("B+") { b += 1 }
                }
            }
            Text("A + B = \(a + b)")
        }
    }
}

/// Root view composing all state demo sections.
public struct StateDemoRootView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("State Management")
                .font(.title)
            Divider()
            Group {
                CounterSection()
                Divider()
                TextToggleSection()
                Divider()
                ConditionalSection()
            }
            Group {
                Divider()
                BindingSection()
                Divider()
                MultiStateSection()
            }
            Spacer()
        }
        .padding()
    }
}
