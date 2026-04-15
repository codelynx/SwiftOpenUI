import Foundation

/// Curated SF Symbols → Material Symbols name translation table.
///
/// Non-macOS backends use this to resolve `Image(systemName:)` calls
/// against the bundled Material Symbols Rounded font: the renderer looks
/// the SF name up in `map`, and — if found — renders the corresponding
/// Material glyph through the same path as `Image(material:)`.
///
/// Unmapped SF names fall through to a visible "missing icon" placeholder
/// (`missingSymbolPlaceholderName`) rather than silent failure, so app
/// developers notice and can either pass a name that's already mapped or
/// file/propose an addition to this table.
///
/// ## Policy notes (see docs/architecture/icon-symbols.md M-Symbols-3)
///
/// - **`.fill` variants collapse to their outlined counterpart** for V1.
///   SF distinguishes `folder` vs `folder.fill`; our single committed
///   static font is outlined-only, so both names map to the same Material
///   glyph. Shipping a filled-companion static is tracked as M-Symbols-3b.
/// - **Swift source file, not JSON**, deliberately — compile-time dedup
///   checks, trivial grep/edit workflow, no runtime parse cost.
/// - **Coverage is demand-driven, not comprehensive.** V1 targets
///   Synca's observed usage plus the common SwiftUI-tutorial icon set
///   (~50 entries). Expansion happens one entry at a time as apps
///   request them; mapping each entry is a small product decision.
public enum SFSymbolCompatibility {
    /// Material Symbols glyph rendered when `Image(systemName:)` is given
    /// a name that has no entry in `map`. Chosen to read as "icon
    /// missing" rather than stray text content. `help_outline` is a
    /// boxed-circle question-mark frame in Material Rounded.
    public static let missingSymbolPlaceholderName: String = "help_outline"

    /// Look up the Material Symbols name corresponding to an SF Symbols
    /// name, or nil if the SF name isn't currently mapped.
    public static func materialName(for sfName: String) -> String? {
        map[sfName]
    }

    /// The curated SF→Material map. Keep alphabetized within each
    /// thematic section to make merge conflicts easy to resolve.
    public static let map: [String: String] = [
        // MARK: Navigation / chevrons
        "chevron.backward":       "chevron_left",
        "chevron.down":           "expand_more",
        "chevron.forward":        "chevron_right",
        "chevron.left":           "chevron_left",
        "chevron.right":          "chevron_right",
        "chevron.up":             "expand_less",

        // MARK: Arrows and motion
        "arrow.backward":         "arrow_back",
        "arrow.clockwise":        "refresh",
        "arrow.counterclockwise": "undo",
        "arrow.down":             "arrow_downward",
        "arrow.forward":          "arrow_forward",
        "arrow.forward.circle.fill": "arrow_circle_right",
        "arrow.left":             "arrow_back",
        "arrow.left.arrow.right": "swap_horiz",
        "arrow.right":            "arrow_forward",
        "arrow.triangle.2.circlepath": "sync",
        "arrow.up":               "arrow_upward",
        "arrow.up.arrow.down":    "swap_vert",

        // MARK: File / folder
        "doc":                    "description",
        "doc.fill":               "description",
        "doc.on.doc":             "content_copy",
        "doc.text":               "description",
        "doc.text.magnifyingglass": "find_in_page",
        "folder":                 "folder",
        "folder.badge.plus":      "create_new_folder",
        "folder.fill":            "folder",
        "trash":                  "delete",
        "trash.fill":             "delete",

        // MARK: Search / find
        "magnifyingglass":        "search",
        "magnifyingglass.circle": "search",

        // MARK: Status / feedback
        "checkmark":              "check",
        "checkmark.circle":       "check_circle",
        "checkmark.circle.fill":  "check_circle",
        "checkmark.seal.fill":    "verified",
        "exclamationmark.triangle": "warning",
        "exclamationmark.triangle.fill": "warning",
        "info.circle":            "info",
        "info.circle.fill":       "info",
        "questionmark":           "help_outline",
        "questionmark.circle":    "help_outline",
        "xmark":                  "close",
        "xmark.circle":           "cancel",
        "xmark.circle.fill":      "cancel",

        // MARK: Common actions
        "gear":                   "settings",
        "gearshape":              "settings",
        "gearshape.fill":         "settings",
        "minus":                  "remove",
        "minus.circle":           "remove_circle",
        "pencil":                 "edit",
        "plus":                   "add",
        "plus.circle":            "add_circle",
        "plus.circle.fill":       "add_circle",
        "square.and.arrow.down":  "download",
        "square.and.arrow.up":    "share",
        "square.and.pencil":      "edit",

        // MARK: People / accounts
        "person":                 "person",
        "person.2":               "group",
        "person.crop.circle":     "account_circle",
        "person.fill":            "person",

        // MARK: UI primitives
        "bell":                   "notifications",
        "bell.fill":              "notifications",
        "bookmark":               "bookmark",
        "calendar":               "calendar_today",
        "clock":                  "schedule",
        "ellipsis":               "more_horiz",
        "ellipsis.circle":        "more_horiz",
        "eye":                    "visibility",
        "eye.slash":              "visibility_off",
        "heart":                  "favorite_border",
        "heart.fill":             "favorite",
        "house":                  "home",
        "house.fill":             "home",
        "link":                   "link",
        "lock":                   "lock",
        "lock.fill":              "lock",
        "lock.open":              "lock_open",
        "star":                   "star_border",
        "star.fill":              "star",
        "tag":                    "label",
        "tag.fill":               "label",
    ]
}
