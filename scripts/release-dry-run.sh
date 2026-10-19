#!/usr/bin/env bash
# Ensayo en seco LOCAL de .github/workflows/release.yml: sin push, sin tags remotos, sin GitHub Release.
#
#   scripts/release-dry-run.sh [versión] [plataformas...]
#
# 1. XCFramework del runtime (DaggerSwiftCore) + zip + checksum.
# 2. dagger-graph.artifactbundle universal + zip + checksum.
# 3. Package.swift de release (url + checksum) y commit solo-para-el-tag en un clon temporal.
# 4. Verificación: consumidor de humo contra un checkout de release con binaryTarget(path:),
#    midiendo build limpio fuente vs. binario, y `swift package dagger-graph` desde el artifactbundle.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.0.0-dryrun}"
shift || true
OUT="$ROOT/.build/release-artifacts"
REPO_URL="${REPO_URL:-https://github.com/fsaldivar-dev/dagger-swift}"
mkdir -p "$OUT"

now() { python3 -c 'import time; print(time.time())'; }
elapsed() { python3 -c "print(f'{$(now) - $1:.1f}')"; }
SUMMARY=()

# ── 1. XCFramework ────────────────────────────────────────────────────────────
T=$(now)
"$ROOT/scripts/build-xcframework.sh" "$OUT" "$@"
(cd "$OUT" && rm -f DaggerSwiftCore.xcframework.zip && ditto -c -k --sequesterRsrc --keepParent DaggerSwiftCore.xcframework DaggerSwiftCore.xcframework.zip)
CORE_SUM="$(swift package compute-checksum "$OUT/DaggerSwiftCore.xcframework.zip")"
SUMMARY+=("xcframework: $(elapsed "$T") s · $(du -h "$OUT/DaggerSwiftCore.xcframework.zip" | cut -f1) zip · checksum $CORE_SUM")

# ── 2. artifactbundle ─────────────────────────────────────────────────────────
T=$(now)
"$ROOT/scripts/build-artifactbundle.sh" "$OUT" "$VERSION"
(cd "$OUT" && rm -f dagger-graph.artifactbundle.zip && ditto -c -k --keepParent dagger-graph.artifactbundle dagger-graph.artifactbundle.zip)
GRAPH_SUM="$(swift package compute-checksum "$OUT/dagger-graph.artifactbundle.zip")"
SUMMARY+=("artifactbundle: $(elapsed "$T") s · $(du -h "$OUT/dagger-graph.artifactbundle.zip" | cut -f1) zip · checksum $GRAPH_SUM")

# ── 3. Manifiesto de release + commit solo-para-el-tag (en un clon temporal) ───
DL="$REPO_URL/releases/download/$VERSION"
python3 -I "$ROOT/scripts/make-release-manifest.py" --in "$ROOT/Package.swift" --out "$OUT/Package.release.swift" \
  --core-url "$DL/DaggerSwiftCore.xcframework.zip" --core-checksum "$CORE_SUM" \
  --graph-url "$DL/dagger-graph.artifactbundle.zip" --graph-checksum "$GRAPH_SUM"

TAGCLONE="$OUT/tag-clone"
rm -rf "${TAGCLONE:?}"
git clone -q --no-hardlinks "$ROOT" "$TAGCLONE"
git -C "$TAGCLONE" checkout -q "$(git -C "$ROOT" rev-parse HEAD)"
cp "$OUT/Package.release.swift" "$TAGCLONE/Package.swift"
git -C "$TAGCLONE" -c user.name="release-bot" -c user.email="release-bot@localhost" \
  commit -q -am "release: $VERSION (binaryTarget DaggerSwiftCore + dagger-graph)"
git -C "$TAGCLONE" tag -f "$VERSION" >/dev/null
SUMMARY+=("tag-only commit (clon temporal): $(git -C "$TAGCLONE" log --oneline -1 "$VERSION")")

# ── 4. Verificación con consumidor ────────────────────────────────────────────
# Checkout de release con binaryTarget(path:) apuntando a los artefactos locales.
RELCO="$OUT/release-checkout"
rm -rf "${RELCO:?}"
rsync -a --exclude .build --exclude .git --exclude .swiftpm "$ROOT/" "$RELCO/"
mkdir -p "$RELCO/Binaries"
cp -R "$OUT/DaggerSwiftCore.xcframework" "$OUT/dagger-graph.artifactbundle" "$RELCO/Binaries/"
python3 -I "$ROOT/scripts/make-release-manifest.py" --in "$ROOT/Package.swift" --out "$RELCO/Package.swift" \
  --core-path Binaries/DaggerSwiftCore.xcframework --graph-path Binaries/dagger-graph.artifactbundle

consumer_build() { # $1 = etiqueta, $2 = ruta del paquete DaggerSwift
  local dir="$OUT/consumer-$1"
  rm -rf "${dir:?}"
  rsync -a --exclude .build "$ROOT/scripts/release-consumer/" "$dir/"
  local t; t=$(now)
  DAGGER_SWIFT_PATH="$2" swift build -c release --package-path "$dir" >"$dir.log" 2>&1 || { tail -30 "$dir.log"; exit 1; }
  local secs; secs=$(elapsed "$t")
  local run; run="$(DAGGER_SWIFT_PATH="$2" swift test --package-path "$dir" 2>&1 | grep -E 'Test run with' | tail -1)"
  [[ "$run" == *"passed"* ]] || { echo "✘ tests del consumidor ($1): $run" >&2; exit 1; }
  SUMMARY+=("consumidor ($1): build limpio release $secs s · macOS: $run")
}
consumer_build fuente "$ROOT"
consumer_build binario "$RELCO"

# iOS Simulator: mismos tests del consumidor contra el XCFramework (si el slice ios-sim existe).
if [ -d "$RELCO/Binaries/DaggerSwiftCore.xcframework/ios-arm64_x86_64-simulator" ]; then
  SIM_ID="$(xcrun simctl list devices available | grep -m1 -E 'iPhone' | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
  T=$(now)
  if (cd "$OUT/consumer-binario" && DAGGER_SWIFT_PATH="$RELCO" xcodebuild test -quiet \
        -scheme ReleaseConsumer -destination "id=$SIM_ID" \
        -derivedDataPath "$OUT/consumer-ios-dd" >"$OUT/consumer-ios.log" 2>&1); then
    SUMMARY+=("consumidor (binario) en iOS Simulator: tests en verde ($(elapsed "$T") s)")
  else
    grep -E "error:|failed|✘" "$OUT/consumer-ios.log" | head -20 >&2
    echo "✘ tests del consumidor en iOS Simulator (log: $OUT/consumer-ios.log)" >&2
    exit 1
  fi
else
  SUMMARY+=("iOS Simulator: omitido (el XCFramework no tiene el slice ios-sim)")
fi

# dagger-graph desde el artifactbundle vía command plugin (sin compilar swift-syntax).
T=$(now)
PLUGIN_OUT="$(DAGGER_SWIFT_PATH="$RELCO" swift package --package-path "$OUT/consumer-binario" dagger-graph --timings 2>&1 | tail -4)"
SUMMARY+=("swift package dagger-graph (artifactbundle, incluye resolve/plugin build): $(elapsed "$T") s")

echo
echo "════════ release dry-run $VERSION ════════"
printf '%s\n' "${SUMMARY[@]}"
echo "── salida del plugin ──"
echo "$PLUGIN_OUT"
echo "Artefactos en $OUT (nada se publicó)."
