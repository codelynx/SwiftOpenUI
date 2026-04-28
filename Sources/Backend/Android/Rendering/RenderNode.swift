import SwiftOpenUI

/// A serializable render tree node for the Android host.
/// Swift walks the SwiftOpenUI view tree and produces a RenderNode tree.
/// The tree is serialized to JSON and sent to Kotlin via JNI.
public class RenderNode {
    public let type: String
    /// Stable structural identity — Int64 hash of the node's position in the view tree.
    public var id: Int64 = 0
    public var props: [String: String] = [:]
    public var layout: [String: Double]? = nil
    public var children: [RenderNode] = []

    public init(type: String) {
        self.type = type
    }

    /// Serialize to a JSON-compatible dictionary.
    public func toDict() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if id != 0 {
            // Serialize as string to avoid JSON double precision loss on Kotlin/Java side
            dict["id"] = String(id)
        }
        if !props.isEmpty {
            dict["props"] = props
        }
        if let layout = layout {
            dict["layout"] = layout
        }
        if !children.isEmpty {
            dict["children"] = children.map { $0.toDict() }
        }
        return dict
    }
}

/// Minimal JSON serializer (no Foundation JSONSerialization dependency).
public func renderNodeToJSON(_ node: RenderNode) -> String {
    // Emit clearFocus on the root window node when programmatic focus was cleared
    if node.type == "window" && androidShouldClearFocus {
        node.props["clearFocus"] = "true"
    }
    return dictToJSON(node.toDict())
}

private func dictToJSON(_ dict: [String: Any]) -> String {
    var parts: [String] = []
    for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
        let jsonKey = "\"\(escapeJSON(key))\""
        let jsonValue = valueToJSON(value)
        parts.append("\(jsonKey):\(jsonValue)")
    }
    return "{\(parts.joined(separator: ","))}"
}

private func valueToJSON(_ value: Any) -> String {
    switch value {
    case let s as String:
        return "\"\(escapeJSON(s))\""
    case let i as Int:
        return "\(i)"
    case let i as Int64:
        return "\(i)"
    case let d as Double:
        return "\(d)"
    case let b as Bool:
        return b ? "true" : "false"
    case let dict as [String: Any]:
        return dictToJSON(dict)
    case let dict as [String: String]:
        return dictToJSON(dict.mapValues { $0 as Any })
    case let arr as [[String: Any]]:
        return "[\(arr.map { dictToJSON($0) }.joined(separator: ","))]"
    case let arr as [Any]:
        return "[\(arr.map { valueToJSON($0) }.joined(separator: ","))]"
    default:
        return "null"
    }
}

private func escapeJSON(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
     .replacingOccurrences(of: "\n", with: "\\n")
     .replacingOccurrences(of: "\t", with: "\\t")
}
