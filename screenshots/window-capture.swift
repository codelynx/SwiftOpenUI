// Finds the CGWindowID for a given PID.
// Usage: swift window-capture.swift <pid>
// Prints the window ID to stdout.

import CoreGraphics

guard CommandLine.arguments.count >= 2,
      let pid = Int32(CommandLine.arguments[1]) else {
    print("Usage: window-capture <pid>")
    exit(1)
}

let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []

for window in windowList {
    guard let wPID = window[kCGWindowOwnerPID as String] as? Int32,
          let wLayer = window[kCGWindowLayer as String] as? Int,
          let wID = window[kCGWindowNumber as String] as? Int,
          wPID == pid, wLayer == 0 else { continue }

    print(wID)
    exit(0)
}

exit(1)
