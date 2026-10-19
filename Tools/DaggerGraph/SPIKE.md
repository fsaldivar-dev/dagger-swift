# dagger-graph — Spike Fase 1 (medición)

Validador compile-time del grafo de DaggerSwift **fuera** del runtime y de las macros.
Paquete separado (`Tools/DaggerGraph`) para que `DaggerSwift` siga con cero dependencias externas.

```bash
swift build -c release --package-path Tools/DaggerGraph
Tools/DaggerGraph/.build/release/dagger-graph --timings Sources/SampleProyect Benchmarks
```

Flags: `--timings` (stderr), `--no-cache`, `--cache <ruta>` (default `.build/dagger-graph-cache.json`).
Salida: `archivo:línea:col: error|warning|note: mensaje`; exit 1 si hay errores.

## Qué valida
1. **Binding faltante**: dependencia (param de función `@Module` o dependencia `@Inject`) que ningún `@Module` provee y que no es tipo `@Inject`.
   Si solo existe un registro imperativo (`bindInstance`, `provide*`) → `warning` en vez de `error`.
2. **Ciclos**: Tarjan SCC sobre tipos; reporta la cadena completa + `note` por arista.
3. **Scope**: `@Singleton` que depende (directo o vía nodos transient) de algo que solo vive en un scope hijo.

## Mediciones (M-series, Swift 6.3.3, binario release)

| Escenario | SampleProyect + Benchmarks (41 archivos, 23 relevantes) | Sintético (2000 archivos, 500 relevantes) | Presupuesto |
|---|---|---|---|
| Frío (sin caché) | 8–17 ms | 135 ms | — |
| Caliente sin cambios | ~2.8 ms | ~25 ms | < 50 ms |
| 1 archivo editado | ~5.3 ms | ~69 ms | < 200 ms |

Build limpio de la herramienta (incluye swift-syntax 600.0.1, resolve aparte ~14 s):
debug ≈ 11.5 s (con y sin `--enable-experimental-prebuilts`: los prebuilts solo aplican a targets macro), release ≈ 154 s.
