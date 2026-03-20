#!/usr/bin/env zsh
# Build all Wasm examples and create per-example HTML pages for Vite.
#
# Usage:
#   cd web && ./build-wasm.sh

set -e
cd "$(dirname "$0")/.."

PRODUCTS=(
    # Showcase
    HelloWorld Stopwatch ColorMixer
    # Parity
    ParityViewsBasic ParityViewsLayout ParityViewsContainers
    ParityModifiers ParityStateData ParityNavigation
    ParityEnvironment ParityGestures ParityAnimation
    ParityFocus ParityAppStructure
)
WEB_EXAMPLES="web/examples"
mkdir -p "$WEB_EXAMPLES"

for product in $PRODUCTS; do
    echo "Building $product for Wasm..."
    swift package --swift-sdk swift-6.2.4-RELEASE_wasm js --product "$product" 2>&1 | tail -1

    # Copy the PackageToJS output to web/examples/<product>/
    PKG_OUT=".build/plugins/PackageToJS/outputs/Package"
    DEST="$WEB_EXAMPLES/$product"
    rm -rf "$DEST"
    cp -r "$PKG_OUT" "$DEST"

    # Create an HTML page for this example
    cat > "$WEB_EXAMPLES/${product}.html" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>SwiftOpenUI — $product</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    </style>
    <script type="importmap">
    {
        "imports": {
            "@aspect-build/browser_wasi_shim": "https://esm.sh/@aspect-build/browser_wasi_shim@0.3.0",
            "@bjorn3/browser_wasi_shim": "https://esm.sh/@bjorn3/browser_wasi_shim@0.3.0"
        }
    }
    </script>
</head>
<body>
    <script type="module">
        import { init } from './$product/index.js';
        try {
            await init();
        } catch (e) {
            document.body.textContent = 'Error: ' + e.message;
            console.error(e);
        }
    </script>
</body>
</html>
HTMLEOF

    echo "  Done: $WEB_EXAMPLES/${product}.html"
done

echo ""
echo "All examples built. Run: cd web && npx vite"
