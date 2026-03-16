/// Protocol that platform backends implement to provide native rendering.
///
/// Each platform (GTK4, Win32, Web) provides a concrete type conforming
/// to this protocol. The backend is responsible for:
/// - Creating native widgets/elements from SwiftOpenUI views
/// - Managing the application lifecycle (run loop)
/// - Handling platform-specific event dispatch
/// - Providing ViewHost implementation for reactive rebuilds
///
/// Usage:
///   let backend = GTK4Backend()  // or Win32Backend(), etc.
///   backend.run(MyApp.self)
public protocol RenderBackend {
    /// Run the application with the given App type.
    func run<A: App>(_ appType: A.Type)
}
