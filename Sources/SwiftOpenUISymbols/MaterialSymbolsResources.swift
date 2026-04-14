import Foundation

/// Locates the bundled Material Symbols font inside this target's resource
/// bundle. Backends call this to obtain a URL they can hand to their
/// platform-specific process-local font registration API
/// (e.g. `FcConfigAppFontAddFile` on Linux, `AddFontResourceExW` with
/// `FR_PRIVATE` on Win32).
///
/// On macOS SwiftOpenUI ships its own icon story via native SF Symbols,
/// so `SwiftOpenUISymbols` is intentionally not depended on from macOS
/// targets — the font is never present in macOS app bundles.
public enum MaterialSymbolsResources {
    /// File URL for the bundled Material Symbols Rounded Regular static
    /// font. Derived from the upstream variable font at axes
    /// `wght=400, FILL=0, GRAD=0, opsz=24`.
    ///
    /// See `Sources/SwiftOpenUISymbols/Resources/README.md` for upstream
    /// provenance (pinned commit, source URL, license).
    public static let roundedRegularFontURL: URL = {
        guard let url = Bundle.module.url(
            forResource: "MaterialSymbolsRounded-Regular",
            withExtension: "ttf"
        ) else {
            preconditionFailure(
                "MaterialSymbolsRounded-Regular.ttf not found in SwiftOpenUISymbols bundle"
            )
        }
        return url
    }()

    /// PostScript family name of the bundled font, used by Pango /
    /// DirectWrite / CoreText to look up the registered font once the
    /// backend has added it to its process-local font config.
    public static let roundedRegularFamilyName: String = "Material Symbols Rounded"
}
