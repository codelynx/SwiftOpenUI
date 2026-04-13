import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

struct GTKWidgetSnapshot: Equatable {
    let typeName: String
    let origin: ViewPoint
    let size: ViewSize
    let hexpand: Bool
    let vexpand: Bool
    let halign: String
    let valign: String
    let children: [GTKWidgetSnapshot]

    func flattened() -> [GTKWidgetSnapshot] {
        [self] + children.flatMap { $0.flattened() }
    }

    func debugLines(indent: String = "") -> [String] {
        let line =
            "\(indent)\(typeName) frame=(x:\(fmt(origin.x)), y:\(fmt(origin.y)), " +
            "w:\(fmt(size.width)), h:\(fmt(size.height))) expand=(\(hexpand), \(vexpand)) " +
            "align=(\(halign), \(valign))"
        return [line] + children.flatMap { $0.debugLines(indent: indent + "  ") }
    }

    func debugDescription() -> String {
        debugLines().joined(separator: "\n")
    }
}

func gtkSnapshotTree(
    root: UnsafeMutablePointer<GtkWidget>,
    size: ViewSize? = nil
) -> GTKWidgetSnapshot {
    let rootSize = size ?? gtkMeasuredSize(of: root)
    gtkAllocate(widget: root, size: rootSize)
    return gtkSnapshotSubtree(widget: root, relativeTo: root)
}

func gtkFindFirstSnapshot(
    in root: GTKWidgetSnapshot,
    where predicate: (GTKWidgetSnapshot) -> Bool
) -> GTKWidgetSnapshot? {
    if predicate(root) { return root }
    for child in root.children {
        if let found = gtkFindFirstSnapshot(in: child, where: predicate) {
            return found
        }
    }
    return nil
}

private func gtkSnapshotSubtree(
    widget: UnsafeMutablePointer<GtkWidget>,
    relativeTo root: UnsafeMutablePointer<GtkWidget>
) -> GTKWidgetSnapshot {
    var children: [GTKWidgetSnapshot] = []
    var child = gtk_widget_get_first_child(widget)
    while let current = child {
        children.append(gtkSnapshotSubtree(widget: current, relativeTo: root))
        child = gtk_widget_get_next_sibling(current)
    }

    return GTKWidgetSnapshot(
        typeName: gtkTestWidgetTypeName(widget),
        origin: gtkTranslatedOrigin(child: widget, in: root),
        size: gtkAllocatedSize(of: widget),
        hexpand: gtk_widget_get_hexpand(widget) != 0,
        vexpand: gtk_widget_get_vexpand(widget) != 0,
        halign: gtkAlignName(gtk_widget_get_halign(widget)),
        valign: gtkAlignName(gtk_widget_get_valign(widget)),
        children: children
    )
}

private func gtkAlignName(_ align: GtkAlign) -> String {
    switch align {
    case GTK_ALIGN_FILL: return "fill"
    case GTK_ALIGN_START: return "start"
    case GTK_ALIGN_END: return "end"
    case GTK_ALIGN_CENTER: return "center"
    case GTK_ALIGN_BASELINE_FILL: return "baseline-fill"
    case GTK_ALIGN_BASELINE_CENTER: return "baseline-center"
    default: return "unknown(\(align.rawValue))"
    }
}

private func fmt(_ value: Double) -> String {
    String(format: "%.1f", value)
}

func gtkMeasuredSize(of widget: UnsafeMutablePointer<GtkWidget>) -> ViewSize {
    var widthMin: Int32 = 0
    var widthNat: Int32 = 0
    var heightMin: Int32 = 0
    var heightNat: Int32 = 0
    gtk_swift_widget_measure(widget, GTK_ORIENTATION_HORIZONTAL, -1, &widthMin, &widthNat)
    gtk_swift_widget_measure(widget, GTK_ORIENTATION_VERTICAL, -1, &heightMin, &heightNat)
    return ViewSize(
        width: Double(max(widthMin, widthNat)),
        height: Double(max(heightMin, heightNat))
    )
}

func gtkAllocate(widget: UnsafeMutablePointer<GtkWidget>, size: ViewSize) {
    gtk_widget_allocate(widget, Int32(size.width), Int32(size.height), -1, nil)
}

func gtkAllocatedSize(of widget: UnsafeMutablePointer<GtkWidget>) -> ViewSize {
    ViewSize(
        width: Double(gtk_widget_get_width(widget)),
        height: Double(gtk_widget_get_height(widget))
    )
}

func gtkTranslatedOrigin(
    child: UnsafeMutablePointer<GtkWidget>,
    in root: UnsafeMutablePointer<GtkWidget>
) -> ViewPoint {
    if child == root {
        return .zero
    }
    var sourcePoint = graphene_point_t()
    graphene_point_init(&sourcePoint, 0, 0)
    var translatedPoint = graphene_point_t()
    _ = gtk_widget_compute_point(child, root, &sourcePoint, &translatedPoint)
    return ViewPoint(x: Double(translatedPoint.x), y: Double(translatedPoint.y))
}

func gtkTestWidgetTypeName(_ widget: UnsafeMutablePointer<GtkWidget>) -> String {
    String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
}
