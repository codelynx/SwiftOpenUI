# SimplePaint tool icons

The palette uses five generated PNGs matching the implemented tools:

| File | Tool behavior |
| --- | --- |
| `pencil.png` | Freehand strokes in the selected color |
| `eraser.png` | White freehand strokes over the white canvas (no transparency erasing) |
| `line.png` | Straight line from drag start to drag end |
| `rectangle.png` | Rectangle outline bounded by the drag endpoints |
| `ellipse.png` | Ellipse outline bounded by the drag endpoints |

All tools use the brush-size setting. Shapes preview while dragging, commit on
release, and participate in Undo/Redo. New clears the drawing and redo history.

## Sizes and locations

- Runtime assets: `Resources/SimplePaint/Tools/{pencil,eraser,line,rectangle,ellipse}.png`
  at the package root. Each image is **96 × 96 pixels**, RGB, with an opaque white
  background. The five runtime files together are about 23 KB.
- Palette: **24 × 24 logical points** inside the existing **36 × 36 point** hit
  area. A 96px source supports 1x through 4x display scaling without upscaling.
- Toolbar: **20 × 20 logical points**, alongside the selected tool name.
- Exact generation prompts: `Artwork/prompts.json`. Generated with the built-in
  `image_gen` tool at 1024 × 1024; runtime exports resized to 96px with macOS
  `sips`. The 1024px masters are not kept in the repository — regenerate from
  `prompts.json` if an icon needs reworking. `Artwork/` is excluded from the
  SwiftPM target and app resources.

The white background is deliberate: the current Win32 resizable file-image
renderer uses `StretchBlt(..., SRCCOPY)`, which does not alpha blend transparent
PNGs. The existing blue button background remains visible around the selected
icon. Files require `.resizable()` followed by an explicit frame; their natural
96px size is not their intended display size.

## Resource loading

- **macOS:** `ToolIcon` resolves the file through `AppBundle.main` and loads it
  with `NSImage`. Images are cached across drawing updates. Missing files fall
  back to native SF Symbols.
- **Linux/Windows:** `Image(resource: "SimplePaint/Tools/pencil.png")` resolves
  through `AppBundle.main`. Development runs find the package-root `Resources/`;
  packaged apps use their own `Resources/` directory.
- **Web:** `ToolIcon` uses a relative `Resources/SimplePaint/Tools/*.png` URL.
  `./web/run.sh SimplePaint` copies the package resources beside its generated
  `index.html`. Custom web deployments must copy that directory too.

Run locally with `swift run SimplePaint`. The existing packaging command
`swift package create-bundle SimplePaint --allow-writing-to-package-directory`
copies package-root resources automatically, including these icons. No asset
catalog or additional SwiftPM resource declaration is required.

## Validation (2026-10-16)

- `swift build --product SimplePaint` passed on macOS.
- `swift package --allow-writing-to-package-directory create-bundle SimplePaint -c debug`
  passed; the packaged app loaded all five generated icons.
- Native macOS UI checks passed for selecting all five tools, pencil drawing,
  erasing, brush-size and color changes, line/rectangle/ellipse drawing, Undo,
  Redo, and New.
- Runtime PNG dimensions and opaque RGB format were checked with `sips`;
  `zsh -n web/run.sh` and `git diff --check` passed.
- GTK4, Win32, and Web execution were not checked in this session.
