#!/usr/bin/env bash
# Regenera los grafos de `dagger-graph generate` versionados en el repo (solo reescribe lo que cambió).
# Uso: scripts/generate-graphs.sh   (CI: después, `git diff --exit-code` detecta código generado obsoleto)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release --package-path Tools/DaggerGraph >/dev/null
G="$(swift build -c release --package-path Tools/DaggerGraph --show-bin-path)/dagger-graph"

"$G" generate --no-cache --out Benchmarks/Tests/DIFrameworksDebateTests/Generated \
  --smoke-tests Benchmarks/Tests/DIFrameworksDebateTests/Generated/DaggerGraphSmokeTests.swift \
  --roots-in Benchmarks --target-module DIFrameworksDebateTests Benchmarks

"$G" generate --no-cache --out Sources/SampleProyect/Tests/AppGraphTests/Generated \
  --smoke-tests Sources/SampleProyect/Tests/AppGraphTests/Generated/DaggerGraphSmokeTests.swift \
  --roots-in Sources/SampleProyect/Tests/AppGraphTests --target-module AppGraphTests \
  --import AppFoundation --import Core --import Services --import Features \
  --import MultiCountryNewsDemo --import FintechMockupDemo \
  Sources/SampleProyect
