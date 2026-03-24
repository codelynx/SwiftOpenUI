#if os(macOS)
import SwiftUI
import MacExampleSupport
#else
import SwiftOpenUI
import Foundation
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif
#if canImport(BackendWeb)
import BackendWeb
#endif
#endif

// MARK: - Document Model

enum PaintTool {
    case pencil
    case eraser
    case line
    case rectangle
    case ellipse

    var label: String {
        switch self {
        case .pencil:    return "Pencil"
        case .eraser:    return "Eraser"
        case .line:      return "Line"
        case .rectangle: return "Rectangle"
        case .ellipse:   return "Ellipse"
        }
    }

    var icon: String {
        switch self {
        case .pencil:    return "✏️"
        case .eraser:    return "🧹"
        case .line:      return "📏"
        case .rectangle: return "⬜"
        case .ellipse:   return "⭕"
        }
    }
}

struct PaintPoint {
    var x: Double
    var y: Double
}

struct PaintColor {
    var r: Double
    var g: Double
    var b: Double

    static let black   = PaintColor(r: 0,    g: 0,    b: 0)
    static let white   = PaintColor(r: 1,    g: 1,    b: 1)
    static let red     = PaintColor(r: 0.85, g: 0.15, b: 0.15)
    static let orange  = PaintColor(r: 0.95, g: 0.55, b: 0.1)
    static let yellow  = PaintColor(r: 0.95, g: 0.85, b: 0.1)
    static let green   = PaintColor(r: 0.2,  g: 0.7,  b: 0.2)
    static let blue    = PaintColor(r: 0.15, g: 0.45, b: 0.9)
    static let purple  = PaintColor(r: 0.55, g: 0.2,  b: 0.8)
    static let gray    = PaintColor(r: 0.5,  g: 0.5,  b: 0.5)
    static let brown   = PaintColor(r: 0.6,  g: 0.35, b: 0.15)

    static let palette: [PaintColor] = [
        .black, .white, .red, .orange, .yellow,
        .green, .blue, .purple, .gray, .brown
    ]
}

struct Stroke {
    var tool: PaintTool
    var points: [PaintPoint]
    var color: PaintColor
    var lineWidth: Double
}

// MARK: - Shared Path Construction

/// Build a Path for the given stroke. Shared across all platforms.
func buildStrokePath(_ stroke: Stroke) -> Path {
    switch stroke.tool {
    case .pencil, .eraser:
        if stroke.points.count == 1 {
            let p = stroke.points[0]
            return Path(ellipseIn: CGRect(
                x: p.x - stroke.lineWidth / 2,
                y: p.y - stroke.lineWidth / 2,
                width: stroke.lineWidth,
                height: stroke.lineWidth
            ))
        } else {
            var path = Path()
            path.move(to: CGPoint(x: stroke.points[0].x, y: stroke.points[0].y))
            for i in 1..<stroke.points.count {
                path.addLine(to: CGPoint(x: stroke.points[i].x, y: stroke.points[i].y))
            }
            return path
        }

    case .line:
        var path = Path()
        guard stroke.points.count >= 2 else { return path }
        path.move(to: CGPoint(x: stroke.points[0].x, y: stroke.points[0].y))
        let end = stroke.points[stroke.points.count - 1]
        path.addLine(to: CGPoint(x: end.x, y: end.y))
        return path

    case .rectangle:
        guard stroke.points.count >= 2 else { return Path() }
        let p0 = stroke.points[0]
        let p1 = stroke.points[stroke.points.count - 1]
        return Path(CGRect(
            x: min(p0.x, p1.x), y: min(p0.y, p1.y),
            width: abs(p1.x - p0.x), height: abs(p1.y - p0.y)
        ))

    case .ellipse:
        guard stroke.points.count >= 2 else { return Path() }
        let p0 = stroke.points[0]
        let p1 = stroke.points[stroke.points.count - 1]
        return Path(ellipseIn: CGRect(
            x: min(p0.x, p1.x), y: min(p0.y, p1.y),
            width: abs(p1.x - p0.x), height: abs(p1.y - p0.y)
        ))
    }
}

/// Whether this stroke should be filled (single-point dot) or stroked.
func strokeIsFill(_ stroke: Stroke) -> Bool {
    (stroke.tool == .pencil || stroke.tool == .eraser) && stroke.points.count == 1
}

/// StrokeStyle for the given stroke.
func strokeStyle(_ stroke: Stroke) -> StrokeStyle {
    StrokeStyle(lineWidth: CGFloat(stroke.lineWidth), lineCap: .round, lineJoin: .round)
}

// MARK: - Platform Render Adapters

#if !os(macOS)
func drawStroke(_ context: DrawingContext, stroke: Stroke) {
    guard !stroke.points.isEmpty else { return }
    let color = stroke.tool == .eraser ? PaintColor.white : stroke.color
    let shading = Shading.color(Color(red: color.r, green: color.g, blue: color.b))
    let path = buildStrokePath(stroke)
    if strokeIsFill(stroke) {
        context.fill(path, with: shading)
    } else {
        context.stroke(path, with: shading, style: strokeStyle(stroke))
    }
}
#endif

#if os(macOS)
func drawStrokeMac(_ context: GraphicsContext, stroke: Stroke) {
    guard !stroke.points.isEmpty else { return }
    let color: SwiftUI.Color = stroke.tool == .eraser
        ? .white
        : SwiftUI.Color(red: stroke.color.r, green: stroke.color.g, blue: stroke.color.b)
    let path = buildStrokePath(stroke)
    if strokeIsFill(stroke) {
        context.fill(path, with: .color(color))
    } else {
        context.stroke(path, with: .color(color), style: strokeStyle(stroke))
    }
}
#endif

// MARK: - Tool Panel

struct ToolPanelView: View {
    @Binding var selectedTool: PaintTool

    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<toolList.count) { i in
                let tool = toolList[i]
                Text(tool.icon)
                    .frame(width: 36, height: 36)
                    .background(selectedTool == tool ? Color.blue : Color.white)
                    .border(Color.gray)
                    .onTapGesture {
                        selectedTool = tool
                    }
            }

            Spacer()
        }
        .padding(4)
    }

    private var toolList: [PaintTool] {
        [.pencil, .eraser, .line, .rectangle, .ellipse]
    }
}

// MARK: - Inspector Panel

struct InspectorView: View {
    @Binding var selectedColor: PaintColor
    @Binding var brushSize: Double

    var body: some View {
        VStack(spacing: 8) {
            Text("Color")
                .font(.headline)

            // Color palette: two rows of 5
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    let c = PaintColor.palette[i]
                    Color(red: c.r, green: c.g, blue: c.b)
                        .frame(width: 22, height: 22)
                        .border(
                            isSelected(c) ? Color.blue : Color.gray
                        )
                        .onTapGesture {
                            selectedColor = c
                        }
                }
            }
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    let c = PaintColor.palette[i + 5]
                    Color(red: c.r, green: c.g, blue: c.b)
                        .frame(width: 22, height: 22)
                        .border(
                            isSelected(c) ? Color.blue : Color.gray
                        )
                        .onTapGesture {
                            selectedColor = c
                        }
                }
            }

            Divider()

            Text("Brush Size")
                .font(.headline)
            Text("\(Int(brushSize))")
            Slider(value: $brushSize, in: 1...20, step: 1)
                .padding(.horizontal, 4)

            Spacer()
        }
        .padding(8)
    }

    private func isSelected(_ c: PaintColor) -> Bool {
        c.r == selectedColor.r && c.g == selectedColor.g && c.b == selectedColor.b
    }
}

// MARK: - Main View

struct SimplePaintView: View {
    @State var committedStrokes: [Stroke] = []
    @State var redoStrokes: [Stroke] = []
    @State var activeStroke: Stroke? = nil
    @State var selectedTool: PaintTool = .pencil
    @State var selectedColor: PaintColor = .black
    @State var brushSize: Double = 3

    static let canvasWidth = 600
    static let canvasHeight = 440

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Button("New") {
                    committedStrokes = []
                    redoStrokes = []
                }
                Button("Undo") {
                    guard !committedStrokes.isEmpty else { return }
                    let last = committedStrokes.removeLast()
                    redoStrokes.append(last)
                }
                Button("Redo") {
                    guard !redoStrokes.isEmpty else { return }
                    let last = redoStrokes.removeLast()
                    committedStrokes.append(last)
                }
                Spacer()
                Text("\(selectedTool.icon) \(selectedTool.label)")
                    .foregroundColor(.gray)
            }
            .padding(8)

            Divider()

            // Main content: tool panel | canvas | inspector
            HStack(spacing: 0) {
                // Left: tool panel
                ToolPanelView(selectedTool: $selectedTool)
                    .frame(width: 54)

                Divider()

                // Center: canvas in scrollable area
                ScrollView([.horizontal, .vertical]) {
                    #if os(macOS)
                    macOSCanvas
                    #else
                    gtkCanvas
                    #endif
                }

                Divider()

                // Right: inspector
                InspectorView(
                    selectedColor: $selectedColor,
                    brushSize: $brushSize
                )
                .frame(width: 160)
            }
        }
    }

    // MARK: - Canvas (SwiftOpenUI / GTK4 / Win32)

    #if !os(macOS)
    var gtkCanvas: some View {
        Canvas(
            width: SimplePaintView.canvasWidth,
            height: SimplePaintView.canvasHeight
        ) { context, width, height in
            // White background
            context.setColor(r: 1, g: 1, b: 1)
            context.rectangle(x: 0, y: 0, width: Double(width), height: Double(height))
            context.fill()

            // Committed strokes
            for stroke in committedStrokes {
                drawStroke(context, stroke: stroke)
            }

            // Active preview stroke
            if let active = activeStroke {
                drawStroke(context, stroke: active)
            }
        }
        .onDrag(
            minimumDistance: 1,
            onChanged: { value in
                let point = PaintPoint(x: value.location.x, y: value.location.y)

                if activeStroke == nil {
                    let start = PaintPoint(x: value.startLocation.x, y: value.startLocation.y)
                    activeStroke = Stroke(
                        tool: selectedTool,
                        points: [start],
                        color: selectedTool == .eraser ? .white : selectedColor,
                        lineWidth: brushSize
                    )
                }

                switch selectedTool {
                case .pencil, .eraser:
                    activeStroke?.points.append(point)
                case .line, .rectangle, .ellipse:
                    if activeStroke!.points.count == 1 {
                        activeStroke?.points.append(point)
                    } else {
                        activeStroke?.points[1] = point
                    }
                }
            },
            onEnded: { value in
                guard var stroke = activeStroke else { return }
                let endPoint = PaintPoint(x: value.location.x, y: value.location.y)
                switch stroke.tool {
                case .pencil, .eraser:
                    stroke.points.append(endPoint)
                case .line, .rectangle, .ellipse:
                    if stroke.points.count > 1 {
                        stroke.points[1] = endPoint
                    } else {
                        stroke.points.append(endPoint)
                    }
                }
                committedStrokes.append(stroke)
                redoStrokes = []
                activeStroke = nil
            }
        )
    }
    #endif

    // MARK: - Canvas (macOS / real SwiftUI)

    #if os(macOS)
    var macOSCanvas: some View {
        SwiftUI.Canvas { context, size in
            // White background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.white)
            )

            for stroke in committedStrokes {
                drawStrokeMac(context, stroke: stroke)
            }
            if let active = activeStroke {
                drawStrokeMac(context, stroke: active)
            }
        }
        .frame(
            width: CGFloat(SimplePaintView.canvasWidth),
            height: CGFloat(SimplePaintView.canvasHeight)
        )
        .border(Color.gray)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let point = PaintPoint(x: value.location.x, y: value.location.y)

                    if activeStroke == nil {
                        let start = PaintPoint(
                            x: value.startLocation.x,
                            y: value.startLocation.y
                        )
                        activeStroke = Stroke(
                            tool: selectedTool,
                            points: [start],
                            color: selectedTool == .eraser ? .white : selectedColor,
                            lineWidth: brushSize
                        )
                    }

                    switch selectedTool {
                    case .pencil, .eraser:
                        activeStroke?.points.append(point)
                    case .line, .rectangle, .ellipse:
                        if activeStroke!.points.count == 1 {
                            activeStroke?.points.append(point)
                        } else {
                            activeStroke?.points[1] = point
                        }
                    }
                }
                .onEnded { value in
                    guard var stroke = activeStroke else { return }
                    let endPoint = PaintPoint(x: value.location.x, y: value.location.y)
                    switch stroke.tool {
                    case .pencil, .eraser:
                        stroke.points.append(endPoint)
                    case .line, .rectangle, .ellipse:
                        if stroke.points.count > 1 {
                            stroke.points[1] = endPoint
                        } else {
                            stroke.points.append(endPoint)
                        }
                    }
                    committedStrokes.append(stroke)
                    redoStrokes = []
                    activeStroke = nil
                }
        )
    }
    #endif
}

// MARK: - App

struct SimplePaintApp: App {
    var body: some Scene {
        #if os(macOS)
        WindowGroup("SimplePaint") {
            SimplePaintView()
        }
        .windowResizability(.contentSize)
        #else
        WindowGroup("SimplePaint") {
            SimplePaintView()
        }
        .defaultWindowSize(width: 960, height: 540)
        #endif
    }
}

// MARK: - Entry Point

#if os(macOS)
MacAppLauncher.run(SimplePaintApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(SimplePaintApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(SimplePaintApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(SimplePaintApp.self)
#else
print("SimplePaint app defined. No backend available on this platform.")
#endif
