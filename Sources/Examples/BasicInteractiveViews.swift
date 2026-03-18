#if canImport(SwiftUI) && os(macOS) && !SWIFTOPENUI_BACKEND
import SwiftUI
#else
import SwiftOpenUI
#endif

// MARK: - Navigation demo

public struct DetailView: View {
    let item: String

    public init(item: String) {
        self.item = item
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text("Detail: \(item)")
                .font(.title)
            Text("You navigated here via NavigationLink.")
            #if os(macOS)
            Text("Press Back or use the sidebar.")
            #else
            Text("Press the back button in the header bar.")
            #endif
        }
        .padding()
        #if !os(macOS)
        .navigationTitle(item)
        #endif
    }
}

public struct NavigationDemo: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Navigation")
                    .font(.title)
                #if os(macOS)
                NavigationLink("Go to Page A") { DetailView(item: "Page A") }
                NavigationLink("Go to Page B") { DetailView(item: "Page B") }
                #else
                NavigationLink("Go to Page A", title: "Page A") {
                    DetailView(item: "Page A")
                }
                NavigationLink("Go to Page B", title: "Page B") {
                    DetailView(item: "Page B")
                }
                #endif
            }
            .padding()
            #if !os(macOS)
            .navigationTitle("Home")
            #endif
        }
    }
}

// MARK: - Gesture demo

public struct GestureDemo: View {
    @State private var tapCount = 0
    @State private var longPressed = false

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("Gestures")
                .font(.title)

            Divider()

            Text("Tapped \(tapCount) times")
                .onTapGesture {
                    tapCount += 1
                }

            Text("Double-tap me")
                .onTapGesture(count: 2) {
                    tapCount += 10
                }

            Divider()

            Text(longPressed ? "Long press detected!" : "Long-press me")
                .onLongPressGesture {
                    longPressed = true
                }

            Button("Reset") {
                tapCount = 0
                longPressed = false
            }
        }
        .padding()
    }
}

// MARK: - Animation demo

public struct AnimationDemo: View {
    @State private var expanded = false
    @State private var dimmed = false

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("Animation")
                .font(.title)

            #if os(Windows)
            Text("(effects apply instantly — no animation on Windows)")
                .font(.caption)
                .foregroundColor(.gray)
            #endif

            Divider()

            Text("Hello, Animations!")
                .scaleEffect(expanded ? 1.5 : 1.0)
                .opacity(dimmed ? 0.3 : 1.0)

            Button("Toggle Scale") {
                withAnimation(.easeInOut(duration: 0.4)) {
                    expanded.toggle()
                }
            }

            Button("Toggle Opacity") {
                withAnimation(.easeIn(duration: 0.3)) {
                    dimmed.toggle()
                }
            }

            Divider()

            Text(expanded ? "Expanded" : "Normal")
            Text(dimmed ? "Dimmed" : "Full opacity")
        }
        .padding()
    }
}

// MARK: - Root view

public struct BasicInteractiveView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Basic Interactive")
                .font(.largeTitle)
            Text("Navigation, Gestures, Animation")
            Divider()
            NavigationDemo()
            Divider()
            GestureDemo()
            Divider()
            AnimationDemo()
        }
        .padding()
    }
}
