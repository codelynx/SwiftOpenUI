import SwiftOpenUI

struct HelloWorldApp: App {
    var body: some Scene {
        WindowGroup("Hello World") {
            Text("Hello, SwiftOpenUI!")
        }
    }
}

// TODO: Backend launch — e.g., GTK4Backend().run(HelloWorldApp.self)
print("HelloWorld app defined. Needs a backend to run.")
