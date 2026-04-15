# Icons and symbols across backends

SwiftUI's `Image(systemName:)` references SF Symbols — Apple's icon font
that's shipped as part of every Apple platform. Non-Apple backends need
an equivalent story: a way to render small, crisp, semantically-named
icons (folder, search, arrow.left, …) consistently across platforms.

This document describes how SwiftOpenUI handles that on each backend,
and what's shipped vs. deferred.

## Design summary

| Backend | Icon source | Bundled? |
|---------|-------------|----------|
| macOS (native SwiftUI) | SF Symbols, provided by the OS | No bundle needed |
| GTK4 (Linux) | Material Symbols Rounded, bundled via `SwiftOpenUISymbols` target | Yes (~1.7 MB static) |
| Win32 (Windows) | Same as GTK4 — adoption pending (follow-up milestone) | Planned |
| Web (Wasm) | Same — adoption pending | Planned |
| Android | Same — adoption pending | Planned |

macOS builds carry zero icon-font weight: SF Symbols are provided by the
OS and the native SwiftUI path draws them directly. Non-Apple backends
bundle Material Symbols because there's no system-provided equivalent
they can rely on universally.

## Why Material Symbols

Google's [Material Symbols][1] is the closest open-source peer to SF
Symbols: ~3,000 named icons under Apache License 2.0, shipped as TTF
fonts that render via OpenType ligature substitution (text "home" →
home-icon glyph). Works in any text-rendering stack that handles
ligatures (Pango, DirectWrite, HarfBuzz).

Alternatives considered:

- **Lucide / Feather / Heroicons** — fewer icons (~1,400 or less),
  different design language. Less SwiftUI-parity when app authors need
  a SwiftUI-concept-equivalent icon.
- **Bootstrap Icons, Phosphor** — similar constraints.
- **GNOME icon themes (Adwaita, etc.)** — system-provided but theme-
  dependent and inconsistent across distros; also not cross-platform.

Material Symbols covers roughly the same semantic space as SF Symbols
for common UI verbs and nouns, ships a single font file, and has no
licensing friction.

[1]: https://github.com/google/material-design-icons

## The `SwiftOpenUISymbols` target

The font ships inside a dedicated SwiftPM target named
`SwiftOpenUISymbols`, under `Sources/SwiftOpenUISymbols/`. Layout:

```
Sources/SwiftOpenUISymbols/
├── MaterialSymbolsResources.swift   ← public Bundle.module accessors
└── Resources/
    ├── MaterialSymbolsRounded-Regular.ttf   (~1.7 MB static font)
    ├── LICENSES/
    │   └── Material-Symbols-Apache-2.0.txt
    └── README.md                    ← upstream provenance & regen steps
```

### Platform gating

The target is declared inside `#if os(Linux)` in `Package.swift` —
meaning macOS and Windows package resolutions **don't see the target at
all**. This is deliberate: SwiftPM resource declarations are not
platform-conditional within a single target, so to guarantee zero icon-
font weight in macOS app bundles, the target has to be absent rather
than conditionally-bundled. Other backends (Win32, Web, Android) will
adopt the target in follow-up milestones, each gated to its own
platform.

### Consumption

Backends that need the font import `SwiftOpenUISymbols` and ask for a
file URL:

```swift
import SwiftOpenUISymbols
let fontURL = MaterialSymbolsResources.roundedRegularFontURL
```

The backend then registers the file with its platform-local font
registry **process-locally** — never installed to the user's system
fonts directory. Process-local registration means the font is visible
only to the running Swift process, disappears on process exit, and
doesn't collide with any system or user-installed Material Symbols
fonts the user may already have.

Platform-specific registration APIs:

| Platform | API | Flag |
|----------|-----|------|
| Linux (FontConfig) | `FcConfigAppFontAddFile(FcConfigGetCurrent(), path)` | App-scope by default |
| Win32 | `AddFontResourceExW(path, FR_PRIVATE, NULL)` | `FR_PRIVATE` |
| Web | `new FontFace(name, url)` + `document.fonts.add(...)` | Per-document |
| Android | `Typeface.createFromAsset(assetManager, "...")` | Per-process |

GTK4's `GTK4Backend.run()` performs this registration once at process
startup before constructing the `GtkApplication`:

```swift
public func run<A: App>(_ appType: A.Type) {
    gtkRegisterBundledIconFont()
    let gtkApp = gtk_application_new(...)
    ...
}
```

## Upstream provenance

The committed TTF is not the upstream variable font (~14.8 MB); it's a
static single-instance derived from it via `fontTools.varLib.instancer`
at axes `wght=400, FILL=0, GRAD=0, opsz=24`. This drops size to
~1.7 MB while keeping all ~3,000 glyphs at Regular weight, outlined
(non-filled) variant.

Regeneration is automated by `Scripts/update-material-symbols.sh`.
The script pins a specific upstream commit SHA (documented in
`Sources/SwiftOpenUISymbols/Resources/README.md`) so re-runs produce
byte-identical output until a maintainer explicitly bumps the SHA.

### License

Apache License 2.0 (upstream's license, unchanged). Bundled in two
places for discoverability:

- `Sources/SwiftOpenUISymbols/Resources/LICENSES/Material-Symbols-Apache-2.0.txt`
  — ships inside the resource bundle so any app can surface it at
  runtime (in an About / Credits dialog, say) by reading it via
  `Bundle.module`.
- `LICENSES/Material-Symbols-Apache-2.0.txt` at the repo root —
  standard third-party-license discoverability for code reviewers and
  automated license scanners.

Apache 2.0 compliance: we retain the license text and Google's
copyright, preserve the NOTICE file (none needed — upstream doesn't
ship one), and state our modification (the instancer axes) in the
`Resources/README.md` provenance block.

## `Image(systemName:)` compatibility — phased roadmap

Bundling the font and rendering its glyphs is **packaging**. Providing
SwiftUI's `Image(systemName: "magnifyingglass")` API on non-Apple
backends so a shared SwiftUI codebase "just works" is **compatibility**
— a strictly larger problem, because SF Symbol names aren't 1:1 with
Material Symbol names.

To avoid overclaiming, SwiftOpenUI splits the work into four phases:

### M-Symbols-1 — Packaging and rendering (current milestone)

Scope: font is bundled, loads process-locally on Linux, Pango renders
glyphs when the family name is selected. Acceptance: a parity example
renders three named glyphs (home, search, folder_open). **No
`Image(systemName:)` compatibility promised yet.**

Delivered in this milestone.

### M-Symbols-2 — Direct Material-name API on non-macOS

Scope: a non-SF API for rendering Material glyphs cross-platform —
`Image(material: "search")`, parallel to `Image(systemName:)`. Apps
that want icons today use `#if os(macOS)` to pick SF names vs. this
new API; no pretense of SF compatibility yet.

**Status: API shipped, GTK4 renders glyphs.**  The `Image(material:)`
initializer and the `.materialSymbol(String)` source case on `Image`
live in `Sources/SwiftOpenUI/Views/Image.swift`. The GTK4 backend
renders them via Pango markup against the `SwiftOpenUISymbols`-
bundled font; Win32 and Web currently render a text placeholder
pending per-backend font adoption. macOS renders the same placeholder
since the font is deliberately absent from macOS bundles — macOS
consumers should write `Image(systemName:)` with SF names and wait
for M-Symbols-3 for cross-platform portability.

### M-Symbols-3 — Curated SF Symbols compatibility map

Scope: `Image(systemName: "magnifyingglass")` resolves on non-macOS
via a curated translation table covering the most common ~150–200 SF
symbols (built from Apple's sample-code usage and Synca's observed
usage). After M-Symbols-3, the same `Image(systemName:)` source
compiles and renders for the supported mapped names on every
backend — macOS renders SF natively, non-macOS looks up the
Material equivalent and renders via the existing `Image(material:)`
path. Unsupported names fall through to a visible "symbol not
found" placeholder rather than silent failure.

**Problem it solves.** `Image(systemName:)` already exists in
SwiftOpenUI and compiles fine on non-macOS — the GTK4 backend
currently maps it to `gtk_image_new_from_icon_name` against the
GTK icon theme. The issue is rendering semantics: Adwaita / Yaru /
Breeze icons differ in name coverage, style, and availability from
SF Symbols, so a SwiftUI app written with `Image(systemName: "magnifyingglass")`
gets a different (or missing) icon on each Linux distro. M-Symbols-3
routes that call through Material Symbols instead for uniform
rendering across distros and platforms.

**Payoff for app authors.** Synca's `#if os(macOS) / #elseif os(Linux)`
branches *around icon references* collapse to a single shared-code
path. Broader shared-code cleanup (removing the rest of
`#elseif os(Linux)` view duplication) still depends on the other
SwiftOpenUI API gaps tracked in `next_steps_shared_codebase.md` —
this milestone doesn't solve those.

**Design decisions** (reviewed 2026-04-14):

1. **`.fill` variants deferred.** SwiftUI distinguishes `folder` vs
   `folder.fill`. Material Symbols handles the same distinction via
   the font's FILL axis (0 = outlined, 1 = filled). Shipping both
   variants requires either a second committed static font (~1.7 MB
   more, total ~3.4 MB of bundled font) or switching to the full
   variable font (~14.8 MB). For V1 of M-Symbols-3, both variants
   map to the same outlined glyph — `folder` and `folder.fill`
   resolve to the same Material `folder`. This is a known visual
   gap vs macOS; acceptance criterion is "doesn't crash or render
   blank," not "pixel-perfect fill/outline contrast." A follow-up
   (call it M-Symbols-3b) adds the filled-companion static if the
   gap becomes practically annoying.

2. **Swift source file for the map, not JSON.** The mapping lives
   in `Sources/SwiftOpenUISymbols/SFSymbolCompatibility.swift` as a
   `public enum SFSymbolCompatibility { public static let map: [String: String] = [...] }`.
   Compile-time checks catch duplicate keys and obvious typos, the
   grep/edit workflow is trivial, and no runtime parsing cost. JSON
   was considered and rejected — the map is static data, zero
   value from runtime malleability.

3. **Visible glyph-box placeholder for unmapped names.** Names not
   in the compatibility map render a dedicated "missing icon"
   Material glyph (candidates: `help_outline` circle, `block`,
   `question_mark` inside a boxed frame) so the result reads as
   "icon is missing" rather than as stray text content. Explicitly
   *not* a literal text `"?"` — that gets mistaken for UI copy.
   Debug builds (`#if DEBUG`) additionally emit a one-line warning
   naming the unmapped SF name so app developers notice.

**Implementation sketch.**

```swift
// Sources/SwiftOpenUISymbols/SFSymbolCompatibility.swift
public enum SFSymbolCompatibility {
    public static let map: [String: String] = [
        // File / folder family
        "folder":             "folder",
        "folder.fill":        "folder",           // .fill merged — see note above
        "folder.badge.plus":  "create_new_folder",
        "doc":                "description",
        ...
        // Navigation
        "chevron.right":      "chevron_right",
        "chevron.down":       "expand_more",
        ...
    ]
}
```

```swift
// Sources/Backend/GTK4/Rendering/GTKRenderer.swift (.systemName case)
case .systemName(let sfName):
    if let materialName = SFSymbolCompatibility.map[sfName] {
        return renderMaterialGlyph(materialName, scale: scale)
    }
    #if DEBUG
    print("[SwiftOpenUI] Image(systemName: \(sfName)) not in Material map — rendering placeholder")
    #endif
    return renderMaterialGlyph("help_outline", scale: scale)  // or whichever placeholder
```

**Documented output.** A new `docs/reference/supported-sf-symbols.md`
lists each SF name the map supports, the Material equivalent, and
any fidelity notes (e.g. `"folder.fill" rendered as outlined`).

### M-Symbols-3b — Filled variant support (optional follow-up)

Scope: ship `MaterialSymbolsRounded-Regular-Filled.ttf` (~1.7 MB)
alongside the existing outlined static, update the renderer to pick
the filled font when an SF name ends in `.fill`, and update the
compatibility map to carry a boolean/enum alongside each Material
name. Only undertaken if `.fill` fidelity becomes a concrete pain
point after M-Symbols-3 ships.

### M-Symbols-4 — Expanding coverage

Scope: respond to real-world demand. Add mappings as apps request
them. No hard acceptance bar; ongoing track. Each added mapping is
a tiny product decision (is Material's `edit_square` really the
best match for SF's `square.and.pencil`? etc.), handled one by one.

## Why phased (rather than all at once)

The SF → Material name translation is a product/compatibility policy
problem, not a mechanical one. Many SF Symbols have no clean Material
equivalent (e.g. Apple-specific glyphs, symbols where Material's
design semantics differ). Shipping an incomplete map inside M-Symbols-1
would promise more compatibility than we've actually earned. Separating
the packaging milestone (objectively shippable once the glyph renders)
from the compatibility milestones (where each added name is a small
product decision) keeps both tracks honest.

## Non-goals

- **System-wide font installation.** Process-local only. Users or
  distro packagers may install `fonts-google-material-symbols` system-
  wide if they prefer; apps won't depend on it.
- **Runtime variable-font axis control.** The bundled static font fixes
  `wght=400, FILL=0, GRAD=0, opsz=24`. SF's `foo.fill` semantics are
  handled in M-Symbols-3 by mapping the `.fill` variants to the same
  outlined Material glyph as their non-filled counterparts — a
  documented visual gap vs macOS, acceptable for V1. Shipping a
  filled-companion static (~1.7 MB added for ~3.4 MB total bundled
  font) or switching to the full variable font (~14.8 MB) is tracked
  as optional milestone M-Symbols-3b.
- **Multiple Material styles (Outlined, Rounded, Sharp).** Only Rounded
  ships, chosen for the closest visual match to SF Symbols. Additional
  styles could be added later if demand exists.
- **Per-app subsetting.** Every non-macOS app currently ships the full
  ~1.7 MB font. A future build plugin could subset based on the app's
  actual icon usage (SwiftUI-calls-analysis) to shrink to ~50 KB, but
  that's its own milestone.
