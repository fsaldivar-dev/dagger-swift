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

## Fase 2

### 4. Validación por raíz de composición
`ScopeContainer.root(modules:)`, `expectGraph(...)`/`expectWhenCondition(...)`, `Modulo.buildGraph(including:)`,
`Modulo.resolve(_:including:)`, `Modulo.whenResolved(_:)` y `makeChildScope(for:modules:)` (sobre una raíz conocida,
encadenada o vía `let x = ...`) se validan por separado, siguiendo `includes` en orden de registro.
Si la cadena del test declara `.unresolvedFailure()`, la raíz incompleta sale como `note` (p. ej. `testModuloFaltante`).
Listas no literales → `warning` "no se pudo validar estáticamente".

### Build-tool plugin
`DaggerGraphBuildPlugin` (en este paquete; en los tags de release, contra el artifactbundle):

```swift
.target(name: "App", plugins: [.plugin(name: "DaggerGraphBuildPlugin", package: "DaggerGraph")])
```

Costo medido en SampleProyect (debug): build sin cambios 351 → 378 ms (+27 ms); 1 archivo 518 → 542 ms (+24 ms).

### `generate`: factories tipadas directas
```bash
scripts/generate-graphs.sh   # regenera Benchmarks/…/Generated y SampleProyect/…/AppGraphTests/Generated
```
Por cada raíz literal: `DaggerGraph_<Módulos>.swift` (singletons + transients) y un archivo por scope
(`+<Scope>.swift`). Sin `resolve`, sin `Any`; `@Precondition` → `guard let` + `throw`, evaluadas primero.
Escribe solo si cambió; borra generados obsoletos. No es thread-safe (como un `lazy var`); `@MainActor` si algún tipo lo es.

Benchmark honesto (Round 4, misma semántica: singleton + scoped cacheado + transient; release, 10.000 resoluciones):

| | ms |
|---|---|
| A mano (piso) | 0.06–0.08 |
| Generado | 0.10–0.16 |
| Motor DAG (`resolve`) | 7.3–12 |
| Round 3 "Explícito" (sin caché, no comparable) | 0.23–0.30 |
| Arranque en frío ×1000: DAG / generado | ~11 ms / ~0.08 ms |

### Multi-paquete (prototipo)
```bash
# En el paquete ServicesKit (CI o plugin): publica su manifiesto
dagger-graph manifest --name ServicesKit --out ServicesKit.daggergraph.json Sources/Services Sources/Core
# En la app: valida/genera uniendo los manifiestos de sus dependencias
dagger-graph --manifest ServicesKit.daggergraph.json Sources/Features
```
El manifiesto (`schema: 1`) lista `provides`, `requires` (lo que el paquete no resuelve solo), `scopes`, `modules`
y los hechos completos por archivo, así la raíz valida y genera sin re-parsear el otro paquete.
Probado: `Features` solo → 6 errores; con el manifiesto de `Services`+`Core` → 0 (4 ms).

Diseño pendiente (no implementado): publicar el manifiesto como recurso/artefacto del paquete y que el
build-tool plugin lo descubra en las dependencias (hoy se pasa la ruta a mano); versionar por hash del
contenido para detectar manifiestos obsoletos; nombres de tipos calificados por módulo (hoy por texto).

### Auditoría de service locator (migraciones desde Dip / Resolver / Swinject)
Detecta `X.register(service: valor as T)` y los pedidos `X.shared.resolve()` / `resolve(T.self)`, tomando el tipo
del contexto (`param: T = resolve()`, `@autoclosure () -> T`, `let x: T = resolve()`). Si se pide un tipo que nunca se
registra → `error` ("crashearía en runtime"); si hay registros sin tipo explícito → `warning` sugiriendo `as T`.

Firefox for iOS (1.632 archivos): 14 registros, 225 pedidos (203 con tipo deducible), 0 hallazgos tras tipar 3
registros; quitar un registro produce el error en la línea exacta del que lo pide. 305 ms en frío, 79 ms en caliente.
Límite: asignaciones sueltas (`self.x = resolve()`) no tienen el tipo a la vista (22 de 225 en Firefox).
