#!/usr/bin/env bash
# Regenerate the bundled Material Symbols static font from upstream.
#
# Downloads the pinned variable font from google/material-design-icons and
# instantiates a static Regular variant via fontTools. Commit the resulting
# file under Sources/SwiftOpenUISymbols/Resources/ alongside this script.
#
# Requires fontTools. On Ubuntu/Debian:
#   sudo apt install python3-fonttools python3-brotli
# Elsewhere:
#   python3 -m venv .venv && source .venv/bin/activate && pip install fonttools brotli
#
# To bump to a newer upstream: edit UPSTREAM_SHA below, rerun this script,
# update the provenance block in Sources/SwiftOpenUISymbols/Resources/README.md.

set -euo pipefail

UPSTREAM_REPO="google/material-design-icons"
UPSTREAM_SHA="229d4d6de51043272fdbb0137652f18f5ff4034b"
UPSTREAM_PATH="variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
LICENSE_PATH="LICENSE"

# Instance axes: Regular weight, outlined (non-filled), normal grade, 24px
# optical size. Matches the committed static Regular variant.
WGHT=400
FILL=0
GRAD=0
OPSZ=24

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_FONT="${REPO_ROOT}/Sources/SwiftOpenUISymbols/Resources/MaterialSymbolsRounded-Regular.ttf"
OUT_LICENSE_RESOURCE="${REPO_ROOT}/Sources/SwiftOpenUISymbols/Resources/LICENSES/Material-Symbols-Apache-2.0.txt"
OUT_LICENSE_ROOT="${REPO_ROOT}/LICENSES/Material-Symbols-Apache-2.0.txt"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "Fetching variable font from ${UPSTREAM_REPO}@${UPSTREAM_SHA}"
curl -sL --fail \
    -o "${TMPDIR}/source.ttf" \
    "https://raw.githubusercontent.com/${UPSTREAM_REPO}/${UPSTREAM_SHA}/${UPSTREAM_PATH}"

echo "Fetching license"
curl -sL --fail \
    -o "${TMPDIR}/LICENSE" \
    "https://raw.githubusercontent.com/${UPSTREAM_REPO}/${UPSTREAM_SHA}/${LICENSE_PATH}"

echo "Instancing at wght=${WGHT} FILL=${FILL} GRAD=${GRAD} opsz=${OPSZ}"
python3 - <<PYEOF
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
font = TTFont("${TMPDIR}/source.ttf")
instance = instantiateVariableFont(font, {
    "wght": ${WGHT},
    "FILL": ${FILL},
    "GRAD": ${GRAD},
    "opsz": ${OPSZ},
})
instance.save("${OUT_FONT}")
PYEOF

echo "Mirroring license"
mkdir -p "$(dirname "${OUT_LICENSE_RESOURCE}")" "$(dirname "${OUT_LICENSE_ROOT}")"
cp "${TMPDIR}/LICENSE" "${OUT_LICENSE_RESOURCE}"
cp "${TMPDIR}/LICENSE" "${OUT_LICENSE_ROOT}"

echo "Done. Files:"
echo "  ${OUT_FONT}"
echo "  ${OUT_LICENSE_RESOURCE}"
echo "  ${OUT_LICENSE_ROOT}"
echo
echo "Remember to update the provenance block in"
echo "  Sources/SwiftOpenUISymbols/Resources/README.md"
echo "if you changed UPSTREAM_SHA."
