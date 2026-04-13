/// A view that creates a hierarchical list of disclosure groups from
/// a collection of identified data with optional children.
///
/// This matches SwiftUI's `OutlineGroup` signature used inside `List`.
/// On backends that don't support native tree widgets, it renders as
/// nested `DisclosureGroup` views.
public struct OutlineGroup<Data, ID, RowContent>: View
where Data: RandomAccessCollection, ID: Hashable, RowContent: View {
    let items: [Data.Element]
    let idKeyPath: KeyPath<Data.Element, ID>
    let childrenKeyPath: KeyPath<Data.Element, Data?>
    let rowContent: (Data.Element) -> RowContent

    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        @ViewBuilder content: @escaping (Data.Element) -> RowContent
    ) {
        self.items = Array(data)
        self.idKeyPath = id
        self.childrenKeyPath = children
        self.rowContent = content
    }

    public var body: some View {
        ForEach(items, id: idKeyPath) { element in
            _OutlineRow(
                element: element,
                idKeyPath: idKeyPath,
                childrenKeyPath: childrenKeyPath,
                rowContent: rowContent
            )
        }
    }
}

/// Helper view that renders a single outline row, recursing into
/// a DisclosureGroup when children exist.
private struct _OutlineRow<Data, ID, RowContent>: View
where Data: RandomAccessCollection, ID: Hashable, RowContent: View {
    let element: Data.Element
    let idKeyPath: KeyPath<Data.Element, ID>
    let childrenKeyPath: KeyPath<Data.Element, Data?>
    let rowContent: (Data.Element) -> RowContent

    var body: some View {
        let kids = element[keyPath: childrenKeyPath]
        if let kids = kids, !kids.isEmpty {
            DisclosureGroup(isExpanded: false) {
                ForEach(Array(kids), id: idKeyPath) { child in
                    _OutlineRow(
                        element: child,
                        idKeyPath: idKeyPath,
                        childrenKeyPath: childrenKeyPath,
                        rowContent: rowContent
                    )
                }
            } label: {
                rowContent(element)
            }
        } else {
            rowContent(element)
        }
    }
}
