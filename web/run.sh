#!/usr/bin/env zsh
# Build a SwiftOpenUI example for Web and serve it in the browser.
#
# Usage:
#   ./web/run.sh HelloWorld
#   ./web/run.sh Counter
#   ./web/run.sh StateDemo

set -e
cd "$(dirname "$0")/.."

PRODUCT="${1:-HelloWorld}"
echo "Building $PRODUCT for Wasm..."

source ~/.swiftly/env.sh
swift package --swift-sdk swift-6.2.4-RELEASE_wasm js --product "$PRODUCT" 2>&1 | tail -1

OUTDIR=".build/plugins/PackageToJS/outputs/Package"

# Generate index.html that loads the Wasm module
cat > "$OUTDIR/index.html" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>SwiftOpenUI — $PRODUCT</title>
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
        import { init } from './index.js';
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

echo "Serving $PRODUCT at http://localhost:3000"
npx serve "$OUTDIR"
