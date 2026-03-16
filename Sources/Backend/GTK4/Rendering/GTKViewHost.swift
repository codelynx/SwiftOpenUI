import CGTK
import CGTKBridge
import SwiftOpenUI
import Foundation

/// Thread-local key for the ViewHost currently performing a rebuild.
private var rebuildingViewHostKey: pthread_key_t = {
    var key: pthread_key_t = 0
    pthread_key_create(&key, nil)
    return key
}()

/// GTK4-specific ViewHost that manages a stable GtkBox container.
/// On state change, rebuilds the body and swaps children.
public class GTKViewHost: AnyViewHost {
    public let container: UnsafeMutablePointer<GtkWidget>
    let buildBody: () -> OpaquePointer
    private let lock = NSLock()
    private var scheduled = false
    private var isContainerAlive = true
    private var suppressFocusRestoreOnce = false
    var capturedEnvironment: EnvironmentValues

    public init(buildBody: @escaping () -> OpaquePointer) {
        self.buildBody = buildBody
        self.capturedEnvironment = getCurrentEnvironment()
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        self.container = box
        gtk_widget_set_hexpand(box, 0)
        gtk_widget_set_vexpand(box, 0)

        // Attach self to the GTK widget for lifetime management.
        let retained = Unmanaged.passRetained(self).toOpaque()
        let gobject = UnsafeMutableRawPointer(box).assumingMemoryBound(to: GObject.self)
        g_object_set_data_full(
            gobject,
            "gtk-swift-view-host",
            retained,
            { userData in
                let hostRef = Unmanaged<GTKViewHost>.fromOpaque(userData!)
                hostRef.takeUnretainedValue().markContainerDestroyed()
                hostRef.release()
            }
        )
    }

    private func markContainerDestroyed() {
        lock.lock()
        isContainerAlive = false
        scheduled = false
        lock.unlock()
    }

    public func scheduleRebuild() {
        lock.lock()
        defer { lock.unlock() }
        guard isContainerAlive else { return }
        guard !scheduled else { return }
        scheduled = true
        let retained = Unmanaged.passRetained(self)
        g_idle_add({ userData -> gboolean in
            let host = Unmanaged<GTKViewHost>.fromOpaque(userData!).takeRetainedValue()
            host.rebuild()
            return 0 // G_SOURCE_REMOVE
        }, retained.toOpaque())
    }

    public func suppressNextFocusRestore() {
        lock.lock()
        suppressFocusRestoreOnce = true
        lock.unlock()
    }

    func rebuild() {
        lock.lock()
        scheduled = false
        guard isContainerAlive else {
            lock.unlock()
            return
        }
        suppressFocusRestoreOnce = false
        lock.unlock()

        g_object_ref(gpointer(container))
        defer { g_object_unref(gpointer(container)) }

        // Remove old children
        while gtk_swift_is_widget(container) != 0, let child = gtk_widget_get_first_child(container) {
            gtk_box_remove(boxPointer(container), child)
        }

        // Set up rebuild context
        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(self)

        // Restore environment for the rebuild pass
        let previousEnv = getCurrentEnvironment()
        setCurrentEnvironment(capturedEnvironment)
        let widget = buildBody()
        setCurrentEnvironment(previousEnv)

        GTKViewHost.setCurrentRebuilding(previousHost)

        let newChild = widgetFromOpaque(widget)
        let childHexpand = gtk_widget_get_hexpand(newChild) != 0
        let childVexpand = gtk_widget_get_vexpand(newChild) != 0
        gtk_widget_set_hexpand(container, childHexpand ? 1 : 0)
        gtk_widget_set_vexpand(container, childVexpand ? 1 : 0)
        gtk_box_append(boxPointer(container), newChild)
    }

    // MARK: - Thread-local rebuild context

    static func getCurrentRebuilding() -> GTKViewHost? {
        guard let ptr = pthread_getspecific(rebuildingViewHostKey) else { return nil }
        return Unmanaged<GTKViewHost>.fromOpaque(ptr).takeUnretainedValue()
    }

    static func setCurrentRebuilding(_ host: GTKViewHost?) {
        if let host = host {
            let ptr = Unmanaged.passUnretained(host).toOpaque()
            pthread_setspecific(rebuildingViewHostKey, ptr)
        } else {
            pthread_setspecific(rebuildingViewHostKey, nil)
        }
    }
}
