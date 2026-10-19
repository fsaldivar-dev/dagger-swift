#!/usr/bin/env bash
# Construye DaggerSwiftCore.xcframework (runtime) con BUILD_LIBRARY_FOR_DISTRIBUTION=YES.
# Uso: scripts/build-xcframework.sh <dir-salida> [plataformas...]
#   plataformas por defecto: ios ios-sim macos maccatalyst tvos tvos-sim watchos watchos-sim visionos visionos-sim
# Trabaja sobre una copia del paquete con un producto dinámico temporal: el Package.swift real no cambia.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mkdir -p "${1:?uso: build-xcframework.sh <dir-salida>}" && cd "$1" && pwd)"
shift
PLATFORMS=("$@")
[ ${#PLATFORMS[@]} -eq 0 ] && PLATFORMS=(ios ios-sim macos maccatalyst tvos tvos-sim watchos watchos-sim visionos visionos-sim)
MODULE=DaggerSwiftCore
WORK="$OUT/xcframework-work"

rm -rf "${WORK:?}" "${OUT:?}/$MODULE.xcframework"
mkdir -p "$WORK/stage"

# 1. Copia mínima del paquete + producto dinámico solo para el runtime.
rsync -a --exclude .build --exclude .git --exclude .swiftpm --exclude Benchmarks --exclude Tools \
  --exclude Sources/SampleProyect --exclude Sources/Demo --exclude Test "$ROOT/" "$WORK/stage/"
python3 -I - "$WORK/stage/Package.swift" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
s = s.replace("products: [", 'products: [\n        .library(name: "DaggerSwiftCore", type: .dynamic, targets: ["DaggerSwiftCore"]),', 1)
# Los tests no se copian: quitar el testTarget para que el manifiesto resuelva.
s = re.sub(r'\n\s*// Target de pruebas[^\n]*\n\s*\.testTarget\(.*?\n\s*\),', '', s, flags=re.S)
open(p, "w").write(s)
PY

destination() {
  case "$1" in
    ios) echo "generic/platform=iOS" ;;
    ios-sim) echo "generic/platform=iOS Simulator" ;;
    macos) echo "generic/platform=macOS" ;;
    maccatalyst) echo "generic/platform=macOS,variant=Mac Catalyst" ;;
    tvos) echo "generic/platform=tvOS" ;;
    tvos-sim) echo "generic/platform=tvOS Simulator" ;;
    watchos) echo "generic/platform=watchOS" ;;
    watchos-sim) echo "generic/platform=watchOS Simulator" ;;
    visionos) echo "generic/platform=visionOS" ;;
    visionos-sim) echo "generic/platform=visionOS Simulator" ;;
    *) echo "plataforma desconocida: $1" >&2; exit 2 ;;
  esac
}

FRAMEWORK_ARGS=()
for P in "${PLATFORMS[@]}"; do
  DEST="$(destination "$P")"
  ARCHIVE="$WORK/$P.xcarchive"
  DD="$WORK/dd-$P"
  echo "▸ $P ($DEST)"
  LOG="$WORK/$P.log"
  if ! (cd "$WORK/stage" && xcodebuild archive \
      -scheme "$MODULE" -destination "$DEST" \
      -archivePath "$ARCHIVE" -derivedDataPath "$DD" \
      SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      DEBUG_INFORMATION_FORMAT=dwarf-with-dsym) >"$LOG" 2>&1; then
    grep -E "error:" "$LOG" | sort -u | head -20 >&2
    echo "✘ $P falló (log completo: $LOG)" >&2
    exit 1
  fi

  FW="$(find "$ARCHIVE/Products" -name "$MODULE.framework" -type d | head -1)"
  [ -n "$FW" ] || { echo "no se encontró $MODULE.framework en $ARCHIVE" >&2; exit 1; }

  # xcodebuild no copia la interfaz Swift dentro del framework de un paquete SPM: se agrega a mano.
  SWIFTMODULE="$(find "$DD/Build/Intermediates.noindex/ArchiveIntermediates" -type d -name "$MODULE.swiftmodule" -path "*BuildProductsPath*" | head -1)"
  [ -n "$SWIFTMODULE" ] || { echo "no se encontró $MODULE.swiftmodule para $P" >&2; exit 1; }
  if [ -d "$FW/Versions/A" ]; then
    MODDIR="$FW/Versions/A/Modules"
    mkdir -p "$MODDIR"
    ln -sfh Versions/Current/Modules "$FW/Modules"
  else
    MODDIR="$FW/Modules"
    mkdir -p "$MODDIR"
  fi
  rm -rf "${MODDIR:?}/$MODULE.swiftmodule"
  cp -R "$SWIFTMODULE" "$MODDIR/"
  # Se conservan los .swiftmodule binarios: con el mismo compilador evitan recompilar la interfaz
  # (medido: +3 s por build limpio del consumidor sin ellos). Con otro compilador se usa el .swiftinterface.
  find "$MODDIR/$MODULE.swiftmodule" -name "*.private.swiftinterface" -type f -delete

  FRAMEWORK_ARGS+=(-framework "$FW")
  DSYM="$ARCHIVE/dSYMs/$MODULE.framework.dSYM"
  [ -d "$DSYM" ] && FRAMEWORK_ARGS+=(-debug-symbols "$DSYM")
done

xcodebuild -create-xcframework "${FRAMEWORK_ARGS[@]}" -output "$OUT/$MODULE.xcframework"
echo "✔ $OUT/$MODULE.xcframework"
