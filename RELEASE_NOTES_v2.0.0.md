# 🗡️ DaggerSwift v2.0.0: Enterprise DI Engine for Swift 6 & Clean Architecture

Nos complace anunciar el lanzamiento estable oficial de **DaggerSwift v2.0.0**, el motor de Inyección de Dependencias y Ciclos de Vida de Memoria diseñado específicamente para **Swift 6, Concurrencia Estricta y Clean Architecture** en iOS, macOS, watchOS, tvOS, visionOS y Linux.

---

## 🌟 Lo más destacado de esta versión

### 1. 🪄 Macros Declarativos de Swift 6
* **`@Module`**: Registro declarativo y tipado sin diccionarios de strings ni reflection runtime.
* **`@Inject(scope:)`**: Genera inicializadores estándar `init(...)` limpios y constructores throwing desde el contenedor.
* **`@Precondition`**: Cortocircuito estricto en RAM. Si el usuario no tiene sesión o las condiciones de negocio no se cumplen, el sub-grafo aborta su instanciación con **0 asignaciones de memoria**.
* **`@BusinessRule`**: Conmutación dinámica de variantes (A/B testing, feature flags) en tiempo de ejecución.
* **`@Scoped` y `@Singleton`**: Distinción determinística entre instancias únicas por scope y singletons globales de aplicación.

### 2. 🛡️ Pureza en Clean Architecture e Inmunidad al Vendor Lock-In
* **Cero Imports en Dominio:** Tus casos de uso y modelos de dominio no dependen de ningún framework de DI.
* **Cero Imports en UI (`*View.swift`):** Las vistas no importan `DaggerSwift`. No existen modificadores propietarios como `.daggerScope` o `.daggerPreview` que aten tu interfaz a la librería.
* **Xcode Previews Nativas en Milisegundos:** Previsualizaciones estándar con constructores puros y mocks sin sobrecarga ni contenedores globales.

### 3. 🧩 Delimitación de Fronteras (El Rompecabezas Enterprise)
DaggerSwift no intenta ser un router ni una máquina de estados de UI:
* **`DaggerSwift`**: Memoria, Grafos, Scopes y `@Preconditions`.
* **`RootComposer`**: Ensamblaje de Vistas y ViewModels.
* **`AppCoordinator`**: Flujos de navegación, modales y Deep Links.
* **`AppEventsBus`**: Comunicación reactiva desacoplada mediante `AsyncStream`.

### 4. 🧠 Auditoría Determinística de Memoria y Ciclos de Vida
* Scopes jerárquicos: `GlobalScope` ➔ `SessionScope` ➔ `FeatureScope`.
* **`teardownScope()`**: Desmantela módulos completos al cerrar pantallas o flujos (*Plug & UnPlug*).
* **`WeakObjectBox`**: Auditoría automática de fugas de memoria y retain cycles en tiempo de desarrollo.

### 5. 🥊 Debate Empírico y Benchmarks Reales (`Benchmarks/`)
Paquete SPM independiente que somete a debate a DaggerSwift contra las principales herramientas del ecosistema Swift:
* **Point-Free `swift-dependencies` (TCA)**
* **Factory (Michael Long)**
* **Swinject**
* Incluye pruebas de fallo cruzado y benchmark empírico (10,000 iteraciones) demostrando resoluciones en **1.35 ms** (explícito) y **19.18 ms** (motor DAG).

### 6. 🧪 Suite de Pruebas `DaggerSwiftTesting`
* DSL declarativo para pruebas del grafo: `expectGraph(...)`, `expectWhenCondition(...)` y `whenResolved(Protocol.self).returns(Fake.self)`.
* **Linter de Arquitectura:** Auditoría automática que verifica la pureza de capas y previene acoplamientos prohibidos.

---

## 📦 Instalación (Swift Package Manager)

Agrega DaggerSwift a tu `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/fsaldivar-dev/dagger-swift.git", from: "2.0.0")
]
```

O en Xcode: `File` ➔ `Add Package Dependencies...` ➔ `https://github.com/fsaldivar-dev/dagger-swift.git`

---

## 📚 Documentación Completa
* 📖 [Manual de Arquitectura y Referencia Completa (README.md)](https://github.com/fsaldivar-dev/dagger-swift#readme)
* 📕 [Libro de Inyección, Variantes y Benchmarks Reales (LIBRO_INYECCION_Y_BENCHMARKS.md)](https://github.com/fsaldivar-dev/dagger-swift/blob/main/LIBRO_INYECCION_Y_BENCHMARKS.md)
