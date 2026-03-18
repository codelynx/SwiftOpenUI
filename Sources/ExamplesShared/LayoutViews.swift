import SwiftOpenUI

public struct VStackSection: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("VStack Alignment")
                .font(.headline)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(".leading")
                        .font(.caption)
                    Text("Short")
                    Text("Medium text")
                    Text("A longer piece of text")
                }
                .padding(4)
                .border(.gray)

                VStack(alignment: .center, spacing: 2) {
                    Text(".center")
                        .font(.caption)
                    Text("Short")
                    Text("Medium text")
                    Text("A longer piece of text")
                }
                .padding(4)
                .border(.gray)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(".trailing")
                        .font(.caption)
                    Text("Short")
                    Text("Medium text")
                    Text("A longer piece of text")
                }
                .padding(4)
                .border(.gray)
            }
        }
    }
}

public struct HStackSection: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("HStack Alignment")
                .font(.headline)
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(".top")
                        .font(.caption)
                    Text("Small")
                        .font(.caption)
                    Text("BIG")
                        .font(.title)
                }
                .padding(4)
                .border(.gray)

                HStack(alignment: .center, spacing: 8) {
                    Text(".center")
                        .font(.caption)
                    Text("Small")
                        .font(.caption)
                    Text("BIG")
                        .font(.title)
                }
                .padding(4)
                .border(.gray)

                HStack(alignment: .bottom, spacing: 8) {
                    Text(".bottom")
                        .font(.caption)
                    Text("Small")
                        .font(.caption)
                    Text("BIG")
                        .font(.title)
                }
                .padding(4)
                .border(.gray)
            }
        }
    }
}

public struct SpacerSection: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("Spacer")
                .font(.headline)

            HStack {
                Text("Left")
                Spacer()
                Text("Right")
            }
            .padding(4)
            .border(.gray)

            HStack {
                Spacer()
                Text("Centered")
                Spacer()
            }
            .padding(4)
            .border(.gray)

            HStack {
                Spacer()
                Text("Right-aligned")
            }
            .padding(4)
            .border(.gray)
        }
    }
}

public struct ZStackSection: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("ZStack")
                .font(.headline)
            ZStack {
                Color.blue.opacity(0.2)
                VStack {
                    Text("Layered on blue")
                    Text("background")
                        .font(.caption)
                }
            }
            .frame(width: 200, height: 80)
        }
    }
}

public struct FrameSection: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("Frame")
                .font(.headline)
            HStack(spacing: 8) {
                Text("100×50")
                    .frame(width: 100, height: 50)
                    .background(.red.opacity(0.2))
                    .border(.red)
                Text("150×50")
                    .frame(width: 150, height: 50)
                    .background(.green.opacity(0.2))
                    .border(.green)
            }
        }
    }
}

public struct NestedSection: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Text("Nested Stacks")
                .font(.headline)
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("Col 1")
                        .font(.caption)
                    Text("A")
                    Text("B")
                }
                .padding(4)
                .background(.orange.opacity(0.1))

                VStack(spacing: 2) {
                    Text("Col 2")
                        .font(.caption)
                    Text("C")
                    Text("D")
                    Text("E")
                }
                .padding(4)
                .background(.purple.opacity(0.1))

                VStack(spacing: 2) {
                    Text("Col 3")
                        .font(.caption)
                    Text("F")
                }
                .padding(4)
                .background(.teal.opacity(0.1))
            }
        }
    }
}

/// Root view composing all layout sections.
public struct LayoutRootView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("Layout")
                .font(.title)
            Divider()
            Group {
                VStackSection()
                Divider()
                HStackSection()
                Divider()
                SpacerSection()
            }
            Group {
                Divider()
                ZStackSection()
                Divider()
                FrameSection()
                Divider()
                NestedSection()
            }
            Spacer()
        }
        .padding()
    }
}
