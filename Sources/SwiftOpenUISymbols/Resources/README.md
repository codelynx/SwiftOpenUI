# SwiftOpenUISymbols — bundled font resources

## Contents

- `MaterialSymbolsRounded-Regular.ttf` — Material Symbols Rounded static font,
  single instance derived from the upstream variable font at axes:
  `wght=400, FILL=0, GRAD=0, opsz=24`. Size ~1.7 MB. Contains all Material
  Symbols glyphs at Regular weight, outlined (non-filled) variant.
- `LICENSES/Material-Symbols-Apache-2.0.txt` — the Apache License 2.0 text
  under which the font is redistributed.

## Provenance

- **Upstream project**: google/material-design-icons
- **Source URL**: https://github.com/google/material-design-icons
- **Pinned commit**: `229d4d6de51043272fdbb0137652f18f5ff4034b`
- **Pinned commit date**: 2026-04-10
- **Fetched**: 2026-04-14
- **Source file**: `variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf`
  (~14.8 MB variable font)
- **Transformation**: instantiated with fontTools `varLib.instancer` at
  `wght=400, FILL=0, GRAD=0, opsz=24` to produce the committed static file.
- **License**: Apache License 2.0 (unchanged, copied verbatim from upstream).

## Regenerating

See `Scripts/update-material-symbols.sh` at the repo root. Requires
fontTools (e.g. `sudo apt install python3-fonttools python3-brotli` on
Ubuntu, or `pip install fonttools brotli` in a venv). The script downloads
the variable font from a pinned upstream SHA and re-runs the instancer,
replacing this file deterministically.

## Notes for consumers

This font is bundled into the `SwiftOpenUISymbols` target. It is loaded
process-locally at app startup by backends that depend on that target
(GTK4 / Win32 / Web / Android) — never installed to the user's system
fonts directory. Backends look it up via `Bundle.module` and register
it with their platform-specific process-scoped font API (FontConfig
on Linux via `FcConfigAppFontAddFile`; `AddFontResourceEx` with
`FR_PRIVATE` on Win32; JS font-face embedding on Web; Typeface.createFromAsset
on Android).

macOS builds do not depend on `SwiftOpenUISymbols` — they use the platform's
native SF Symbols via SwiftUI. The font is absent from macOS bundles.
