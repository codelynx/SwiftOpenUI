import SwiftOpenUI

public struct Showcase2View: View {
    public init() {}

    public var body: some View {
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
