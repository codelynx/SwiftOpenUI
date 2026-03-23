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
#if canImport(JavaScriptKit)
import BackendWeb
#endif
#endif

import Foundation
#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

// MARK: - Timer Engine

class StopwatchEngine: ObservableObject {
    @Published var elapsed: TimeInterval = 0
    @Published var laps: [TimeInterval] = []
    @Published var isRunning = false

    private var startDate: Date?
    private var accumulatedTime: TimeInterval = 0
    private var lapStartTime: TimeInterval = 0

    #if canImport(JavaScriptKit)
    private var intervalID: JSValue?
    private var tickClosure: JSClosure?
    #else
    private var timer: Timer?
    #endif

    func startStop() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    func resetOrLap() {
        if isRunning {
            lap()
        } else {
            reset()
        }
    }

    private func start() {
        startDate = Date()
        isRunning = true

        #if canImport(JavaScriptKit)
        let closure = JSClosure { [weak self] _ in
            self?.tick()
            return .undefined
        }
        tickClosure = closure
        intervalID = JSObject.global.setInterval!(closure, 33)
        #else
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        #endif
    }

    private func stop() {
        #if canImport(JavaScriptKit)
        if let id = intervalID {
            _ = JSObject.global.clearInterval!(id)
            intervalID = nil
        }
        tickClosure = nil
        #else
        timer?.invalidate()
        timer = nil
        #endif

        accumulatedTime = elapsed
        startDate = nil
        isRunning = false
    }

    private func lap() {
        let lapTime = elapsed - lapStartTime
        laps.insert(lapTime, at: 0)
        lapStartTime = elapsed
    }

    private func reset() {
        elapsed = 0
        accumulatedTime = 0
        startDate = nil
        laps = []
        lapStartTime = 0
    }

    private func tick() {
        guard let start = startDate else { return }
        elapsed = accumulatedTime + Date().timeIntervalSince(start)
    }
}

// MARK: - Formatting

func formatTime(_ interval: TimeInterval) -> String {
    let totalCentiseconds = Int(interval * 100)
    let minutes = totalCentiseconds / 6000
    let seconds = (totalCentiseconds % 6000) / 100
    let centis = totalCentiseconds % 100
    return String(format: "%02d:%02d.%02d", minutes, seconds, centis)
}

// MARK: - Views

struct StopwatchView: View {
    @ObservedObject var engine = StopwatchEngine()

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // Time display
            Text(formatTime(engine.elapsed))
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(.white)
                .padding(.bottom, 8)

            // Control buttons
            HStack(spacing: 20) {
                // Left button: Reset (when stopped) / Lap (when running)
                Button(action: { engine.resetOrLap() }) {
                    Text(engine.isRunning ? "Lap" : "Reset")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 40)
                        .background(Color(red: 1.0, green: 0.58, blue: 0.0))
                }

                // Right button: Start / Stop
                Button(action: { engine.startStop() }) {
                    Text(engine.isRunning ? "Stop" : "Start")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 40)
                        .background(engine.isRunning
                            ? Color(red: 0.6, green: 0.15, blue: 0.15)
                            : Color(red: 0.15, green: 0.5, blue: 0.2))
                }
            }

            Spacer()

            Divider()

            // Lap list
            if !engine.laps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<engine.laps.count) { i in
                        HStack {
                            Text("Lap \(engine.laps.count - i)")
                                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                .frame(width: 60)
                            Spacer()
                            Text(formatTime(engine.laps[i]))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            } else {
                Spacer()
            }
        }
        .frame(minWidth: 640, minHeight: 420)
        .padding()
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }
}

struct StopwatchApp: App {
    var body: some Scene {
        WindowGroup("Stopwatch") {
            StopwatchView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(StopwatchApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(StopwatchApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(StopwatchApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(StopwatchApp.self)
#else
print("Stopwatch app defined. No backend available on this platform.")
#endif
