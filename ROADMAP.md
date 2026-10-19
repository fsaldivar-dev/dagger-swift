# Roadmap — CI/CD binario + validación compile-time

Estado al 2026-10-19. Ramas locales: `spike/dagger-graph` → `ci/release-binaries` (sin push).

Responsable: **F** = Francisco · **C** = Claude (en la Mac de Francisco).

## 1. Primer release real (bloqueante)

- [x] Spike `dagger-graph`: medición (sin cambios ~3 ms, 1 archivo ~5 ms) — C
- [x] Split `DaggerSwiftCore` (runtime binario) + `DaggerSwift` (macros, fuente) — C
- [x] `ci.yml` (fuente) y `release.yml` (XCFramework + artifactbundle) + ensayo en seco local — C
- [ ] Cambiar el release a `workflow_dispatch` (crea el tag sobre el commit binario, sin moverlo) — C
- [ ] Push de las ramas y PR — C (requiere OK de F)
- [ ] Settings › Actions › Workflow permissions: *Read and write*; sin protección de force-push en tags `v*` (si se mantiene mover tag) — F
- [ ] Primera corrida de CI en GitHub: confirmar Swift 6 + platforms tvOS/watchOS/visionOS en `macos-15` — C/F
- [ ] Definir versión (propuesta: `v2.1.0`; ojo: nombres de tipos del runtime en snapshots pasan a `DaggerSwiftCore.X`) — F
- [ ] Primer release real — F dispara, C revisa

## 2. Deuda a cerrar pronto

- [ ] Linux: guardar `objc_setAssociatedObject` con `#if canImport(ObjectiveC)` o quitar Linux de las notas — C
- [ ] Agregar `.visionOS` a `platforms` (las notas lo prometen) — C
- [ ] Smoke test del consumidor en iOS Simulator dentro de `release.yml` — C
- [ ] Revisar el "known issue" de los tests de Benchmarks (¿intencional?) — F/C

## 3. dagger-graph — Fase 2

- [ ] Validación por raíz de composición (`expectGraph(...)`, `root(modules:)`, `includes`) — cierra el falso negativo de `testModuloFaltante` — C
- [ ] Build-tool plugin (`prebuildCommand`) para validar en cada build (~3–5 ms con caché) — C

## 4. Opcional

- [ ] Firmar el XCFramework (`codesign`) — F (requiere certificado)
- [ ] README: flujo dev (fuente) vs. release (binario) y uso de `swift package dagger-graph` — C
