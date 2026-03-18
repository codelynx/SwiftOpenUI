import SwiftOpenUI

public struct TextStylesView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Large Title").font(.largeTitle)
            Text("Title").font(.title)
            Text("Title 2").font(.title2)
            Text("Title 3").font(.title3)
            Text("Headline").font(.headline)
            Text("Subheadline").font(.subheadline)
            Text("Body").font(.body)
            Text("Callout").font(.callout)
            Text("Footnote").font(.footnote)
            Text("Caption").font(.caption)
            Text("Caption 2").font(.caption2)
        }
        .padding()
    }
}

public struct ColorTextView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Named Colors")
                .font(.headline)
            Text("Red text").foregroundColor(.red)
            Text("Blue text").foregroundColor(.blue)
            Text("Green text").foregroundColor(.green)
            Text("Orange text").foregroundColor(.orange)
            Text("Purple text").foregroundColor(.purple)
            Text("Pink text").foregroundColor(.pink)
            Text("Teal text").foregroundColor(.teal)
            Text("Indigo text").foregroundColor(.indigo)

            Divider()

            Text("Opacity")
                .font(.headline)
            HStack(spacing: 8) {
                Text("100%").foregroundColor(.blue)
                Text("75%").foregroundColor(.blue.opacity(0.75))
                Text("50%").foregroundColor(.blue.opacity(0.5))
                Text("25%").foregroundColor(.blue.opacity(0.25))
            }
        }
        .padding()
    }
}
