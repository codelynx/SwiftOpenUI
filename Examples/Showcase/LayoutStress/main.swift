// LayoutStress — advanced layout parity showcase
//
// Exercises the hard composition patterns that break backends:
// - Settings rows (label + spacer + value, fixed height, full width)
// - Sidebar/detail split with variable-height content
// - Cards with mixed fixed/flexible children
// - Nested frames with competing alignments
// - Status bars with multi-section spacing
// - Form-like rows with different control widths
//
// Run on macOS to see SwiftUI reference, then compare visually on
// each platform. Also serves as a source for new parity scenarios.

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

// MARK: - Section 1: Settings Screen

struct SettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("GENERAL")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            // Settings rows — the classic label/value pattern
            settingsRow("Username", value: "kaz.yoshikawa")
            settingsDivider()
            settingsRow("Email", value: "kaz@example.com")
            settingsDivider()
            settingsRow("Language", value: "English")
            settingsDivider()

            // Row with long value that tests truncation vs expansion
            settingsRow("Storage Path", value: "/Users/kyoshikawa/Documents/Projects")
            settingsDivider()

            // Row with short label, tests leading alignment stability
            settingsRow("ID", value: "12345678")
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
    }

    func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    func settingsDivider() -> some View {
        Color.gray
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

// MARK: - Section 2: Dashboard Cards

struct DashboardSection: View {
    var body: some View {
        VStack(spacing: 12) {
            // Two equal-width cards side by side
            HStack(spacing: 12) {
                card(title: "Downloads", value: "1,234", color: .blue)
                card(title: "Uploads", value: "567", color: .green)
            }

            // Three cards — tests equal division with odd count
            HStack(spacing: 12) {
                card(title: "CPU", value: "45%", color: .orange)
                card(title: "Memory", value: "2.1 GB", color: .red)
                card(title: "Disk", value: "128 GB", color: .purple)
            }

            // One wide card — tests full-width expansion
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("All systems operational")
                        .foregroundColor(.green)
                }
                Spacer()
                Text("99.9%")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        }
    }

    func card(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
    }
}

// MARK: - Section 3: Sidebar/Detail Split

struct SidebarDetailSection: View {
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar — fixed width, variable-height items
            VStack(alignment: .leading, spacing: 0) {
                sidebarItem("Inbox", count: "12", selected: true)
                sidebarItem("Sent", count: "3", selected: false)
                sidebarItem("Drafts", count: "1", selected: false)
                sidebarItem("Archive", count: "847", selected: false)
                Spacer()
            }
            .frame(width: 140)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))

            // Divider
            Color.gray
                .frame(width: 1)

            // Detail — fills remaining space
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Inbox")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("12 items")
                        .foregroundColor(.gray)
                }

                // Message preview rows — mixed-height content
                messageRow("Build Report", preview: "All 698 tests passed on Linux.", time: "2m ago")
                messageRow("Layout Parity", preview: "GTK: 49/50 pass. Win32: 37/50 pass. See attached diff report for structural failures.", time: "15m ago")
                messageRow("Merge Request", preview: "Ready to review.", time: "1h ago")

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 250)
    }

    func sidebarItem(_ label: String, count: String, selected: Bool) -> some View {
        HStack {
            Text(label)
                .foregroundColor(selected ? .blue : .white)
            Spacer()
            Text(count)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selected ? Color(red: 0.2, green: 0.2, blue: 0.3) : Color.clear)
    }

    func messageRow(_ title: String, preview: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                Spacer()
                Text(time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Text(preview)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Section 4: Nested Frame Alignment Stress

struct AlignmentStressSection: View {
    var body: some View {
        HStack(spacing: 12) {
            // Top-leading in outer, bottom-trailing in inner
            ZStack {
                Color(red: 0.2, green: 0.1, blue: 0.1)
                Text("TL")
                    .foregroundColor(.red)
                    .frame(width: 80, height: 60, alignment: .bottomTrailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 120, height: 100)

            // Center in outer, leading in inner
            ZStack {
                Color(red: 0.1, green: 0.2, blue: 0.1)
                VStack(alignment: .leading, spacing: 4) {
                    Text("A")
                        .foregroundColor(.green)
                    Text("BB")
                        .foregroundColor(.green)
                    Text("CCC")
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .frame(width: 120, height: 100)

            // Bottom-trailing with padding — tests padding/frame order
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.2)
                Text("BR")
                    .foregroundColor(.blue)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(width: 120, height: 100)
        }
    }
}

// MARK: - Section 5: Status Bar

struct StatusBarSection: View {
    var body: some View {
        // Multi-section status bar — the Synca pattern that found the original bugs
        HStack(spacing: 0) {
            // Left section — icon + text
            HStack(spacing: 6) {
                Color.green
                    .frame(width: 8, height: 8)
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)

            // Divider
            Color.gray
                .frame(width: 1, height: 16)

            // Center section — fills remaining space
            Text("3 files synced")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)

            // Divider
            Color.gray
                .frame(width: 1, height: 16)

            // Right section — multiple items
            HStack(spacing: 12) {
                Text("45%")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("2.1 MB/s")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 28)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
    }
}

// MARK: - App

struct LayoutStressView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            Text("Layout Stress Test")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(red: 0.1, green: 0.1, blue: 0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("1. Settings Rows")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                    SettingsSection()

                    Text("2. Dashboard Cards")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                    DashboardSection()
                        .padding(.horizontal, 16)

                    Text("3. Sidebar / Detail")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                    SidebarDetailSection()

                    Text("4. Nested Alignment Stress")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                    AlignmentStressSection()
                        .padding(.horizontal, 16)

                    Text("5. Status Bar")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                    StatusBarSection()
                }
                .padding(.vertical, 16)
            }
        }
        .background(Color.black)
    }
}

struct LayoutStressApp: App {
    var body: some Scene {
        WindowGroup("Layout Stress Test") {
            LayoutStressView()
        }
    }
}

#if os(macOS)
MacAppLauncher.run(LayoutStressApp.self)
#elseif canImport(BackendGTK4)
GTK4Backend().run(LayoutStressApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(LayoutStressApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(LayoutStressApp.self)
#endif
