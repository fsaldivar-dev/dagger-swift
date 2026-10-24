#!/usr/bin/env bash
# Construye dagger-graph.artifactbundle (binario universal arm64 + x86_64 de macOS) con info.json.
# Uso: scripts/build-artifactbundle.sh <dir-salida> <versión>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mkdir -p "${1:?uso: build-artifactbundle.sh <dir-salida> <versión>}" && cd "$1" && pwd)"
VERSION="${2:?falta versión}"
NAME=dagger-graph
BUNDLE="$OUT/$NAME.artifactbundle"
VARIANT="$NAME-$VERSION-macos"

swift build -c release --arch arm64 --arch x86_64 --package-path "$ROOT/Tools/DaggerGraph"
BIN="$(swift build -c release --arch arm64 --arch x86_64 --package-path "$ROOT/Tools/DaggerGraph" --show-bin-path)/$NAME"
lipo -info "$BIN"

rm -rf "${BUNDLE:?}"
mkdir -p "$BUNDLE/$VARIANT/bin"
cp "$BIN" "$BUNDLE/$VARIANT/bin/$NAME"
strip -x "$BUNDLE/$VARIANT/bin/$NAME" || true
cat > "$BUNDLE/info.json" <<JSON
{
  "schemaVersion": "1.0",
  "artifacts": {
    "$NAME": {
      "version": "$VERSION",
      "type": "executable",
      "variants": [
        {
          "path": "$VARIANT/bin/$NAME",
          "supportedTriples": ["arm64-apple-macosx", "x86_64-apple-macosx"]
        }
      ]
    }
  }
}
JSON
echo "✔ $BUNDLE"
