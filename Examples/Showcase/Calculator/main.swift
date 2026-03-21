// Calculator — iOS-style calculator using Grid/GridRow layout
//
// Demonstrates: Grid, GridRow, .gridCellColumns(), @State, Button,
// .background(), .foregroundColor(), .font(), .frame()

#if os(macOS)
import SwiftUI
import MacExampleSupport
#else
import SwiftOpenUI
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

// MARK: - Calculator logic

enum Operation {
    case add, subtract, multiply, divide, none
}

struct CalculatorView: View {
    static let buttonSize = 56.0
    static let gridSpacing = 1.0
    static let displayHeight = 96.0
    static let windowWidth = buttonSize * 4 + gridSpacing * 3
    static let windowHeight = displayHeight + buttonSize * 5 + gridSpacing * 4

    @State var display = "0"
    @State var currentValue: Double = 0
    @State var pendingOperation: Operation = .none
    @State var shouldResetDisplay = false

    // Button colors
    let digitBg = Color(red: 0.2, green: 0.2, blue: 0.2)
    let opBg = Color(red: 1.0, green: 0.62, blue: 0.04)
    let fnBg = Color(red: 0.65, green: 0.65, blue: 0.65)
    let buttonSize = CalculatorView.buttonSize
    let gridSpacing = CalculatorView.gridSpacing
    let displayHeight = CalculatorView.displayHeight

    var calculatorWidth: Double { CalculatorView.windowWidth }
    var calculatorHeight: Double { CalculatorView.windowHeight }

    var body: some View {
        // Outer container — fills window with black, centers calculator
        ZStack {
            Color.black

            // Calculator box — fixed size
            VStack(spacing: 0) {
                // Display
                HStack {
                    Spacer()
                    Text(display)
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .frame(height: displayHeight)

                // Button grid
                Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                    GridRow {
                        calcBtn("AC", bg: fnBg, fg: .black) { clear() }
                        calcBtn("+/-", bg: fnBg, fg: .black) { toggleSign() }
                        calcBtn("%", bg: fnBg, fg: .black) { percent() }
                        calcBtn("/", bg: opBg, fg: .white) { setOperation(.divide) }
                    }
                    GridRow {
                        calcBtn("7", bg: digitBg, fg: .white) { appendDigit("7") }
                        calcBtn("8", bg: digitBg, fg: .white) { appendDigit("8") }
                        calcBtn("9", bg: digitBg, fg: .white) { appendDigit("9") }
                        calcBtn("x", bg: opBg, fg: .white) { setOperation(.multiply) }
                    }
                    GridRow {
                        calcBtn("4", bg: digitBg, fg: .white) { appendDigit("4") }
                        calcBtn("5", bg: digitBg, fg: .white) { appendDigit("5") }
                        calcBtn("6", bg: digitBg, fg: .white) { appendDigit("6") }
                        calcBtn("-", bg: opBg, fg: .white) { setOperation(.subtract) }
                    }
                    GridRow {
                        calcBtn("1", bg: digitBg, fg: .white) { appendDigit("1") }
                        calcBtn("2", bg: digitBg, fg: .white) { appendDigit("2") }
                        calcBtn("3", bg: digitBg, fg: .white) { appendDigit("3") }
                        calcBtn("+", bg: opBg, fg: .white) { setOperation(.add) }
                    }
                    GridRow {
                        calcBtn("0", bg: digitBg, fg: .white) { appendDigit("0") }
                        calcBtn("00", bg: digitBg, fg: .white) { appendDigit("00") }
                        calcBtn(".", bg: digitBg, fg: .white) { appendDot() }
                        calcBtn("=", bg: opBg, fg: .white) { evaluate() }
                    }
                }
            }
            .frame(width: calculatorWidth)
            .background(Color.black)
        }
        .frame(width: calculatorWidth, height: calculatorHeight)
    }

    // MARK: - Styled button

    func calcBtn(_ label: String, bg: Color, fg: Color,
                  action: @escaping () -> Void) -> some View {
        Text(label)
            .font(.system(size: 20, weight: .regular))
            .foregroundColor(fg)
            .frame(width: 56, height: 56)
            .background(bg)
            .onTapGesture { action() }
    }

    // MARK: - Calculator actions

    func appendDigit(_ d: String) {
        if shouldResetDisplay || display == "0" {
            display = d
            shouldResetDisplay = false
        } else {
            display = display + d
        }
    }

    func appendDot() {
        if shouldResetDisplay {
            display = "0."
            shouldResetDisplay = false
        } else if !display.contains(".") {
            display = display + "."
        }
    }

    func clear() {
        display = "0"
        currentValue = 0
        pendingOperation = .none
        shouldResetDisplay = false
    }

    func toggleSign() {
        if display.hasPrefix("-") {
            display = String(display.dropFirst())
        } else if display != "0" {
            display = "-" + display
        }
    }

    func percent() {
        if let val = Double(display) {
            display = formatResult(val / 100.0)
        }
    }

    func setOperation(_ op: Operation) {
        if let val = Double(display) {
            if pendingOperation != .none && !shouldResetDisplay {
                performOperation(with: val)
            } else {
                currentValue = val
            }
        }
        pendingOperation = op
        shouldResetDisplay = true
    }

    func evaluate() {
        guard pendingOperation != .none else { return }
        if let val = Double(display) {
            performOperation(with: val)
        }
        pendingOperation = .none
        shouldResetDisplay = true
    }

    func performOperation(with secondValue: Double) {
        let result: Double
        switch pendingOperation {
        case .add:      result = currentValue + secondValue
        case .subtract: result = currentValue - secondValue
        case .multiply: result = currentValue * secondValue
        case .divide:   result = secondValue != 0 ? currentValue / secondValue : 0
        case .none:     result = secondValue
        }
        currentValue = result
        display = formatResult(result)
    }

    func formatResult(_ value: Double) -> String {
        if value == Double(Int(value)) && !value.isInfinite && !value.isNaN {
            return String(Int(value))
        }
        return String(format: "%.8g", value)
    }
}

// MARK: - App

struct CalculatorApp: App {
    var body: some Scene {
        #if os(macOS)
        WindowGroup("Calculator") {
            CalculatorView()
        }
        .windowResizability(.contentSize)
        #else
        WindowGroup("Calculator") {
            CalculatorView()
        }
        .defaultWindowSize(
            width: CalculatorView.windowWidth,
            height: CalculatorView.windowHeight
        )
        .windowSizing(.contentFixed)
        #endif
    }
}

#if os(macOS)
MacAppLauncher.run(CalculatorApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(CalculatorApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(CalculatorApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(CalculatorApp.self)
#else
print("Calculator app defined. No backend available on this platform.")
#endif
