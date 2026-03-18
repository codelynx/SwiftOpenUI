#if canImport(SwiftUI) && os(macOS) && !SWIFTOPENUI_BACKEND
import SwiftUI
#else
import SwiftOpenUI
#endif

public struct TextFieldDemoView: View {
    @State private var name: String = ""
    @State private var email: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("TextField Demo").font(.title)

            Divider()

            VStack(spacing: 4) {
                Text("Name").font(.headline)
                TextField("Enter your name", text: $name)
                Text("Hello, \(name.isEmpty ? "stranger" : name)!")
                    .foregroundColor(.blue)
            }

            Divider()

            VStack(spacing: 4) {
                Text("Email").font(.headline)
                TextField("Enter your email", text: $email)
                if !email.isEmpty {
                    Text("Email: \(email)")
                        .foregroundColor(.green)
                }
            }

            Divider()

            VStack(spacing: 4) {
                Text("Combined").font(.headline)
                if !name.isEmpty && !email.isEmpty {
                    Text("\(name) <\(email)>")
                }
                Button("Clear All") {
                    name = ""
                    email = ""
                }
            }
        }
        .padding()
    }
}
