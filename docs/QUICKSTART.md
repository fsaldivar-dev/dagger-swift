# Quick Start: DaggerSwift en 10 minutos

Cómo se usa, en el orden en que se escribe, y **lo que no debes hacer aunque compile**. El manual completo
está en el [README](../README.md); la política de errores, en [COORDINATOR.md](COORDINATOR.md).

La idea en una frase: **declaras** qué construye cada cosa (`@Module`), **declaras** qué necesita cada
cosa (`@Inject`), **listas** qué existe en cada nivel de la app (`@AppCompose` / `@Compose`), y la
librería genera el cableado. Nadie llama a `resolve` salvo el código generado.

---

## 0. Instalación

```swift
// Package.swift
dependencies: [
    // Mientras no haya release publicado, fija un commit; después `from: "2.1.0"`.
    .package(url: "https://github.com/fsaldivar-dev/dagger-swift", revision: "<commit>"),
],
targets: [
    .target(name: "App", dependencies: [.product(name: "DaggerSwift", package: "dagger-swift")]),
]
```

- Desde Xcode, la primera vez pide **habilitar la macro** `DaggerSwiftMacros`. Desde línea de comandos:
  `xcodebuild … -skipMacroValidation -skipPackagePluginValidation`.
- Al actualizar la librería haz un build limpio: SwiftPM no recompila los archivos que usan macros cuando
  cambia el plugin.

---

## 1. Declara qué construye cada cosa: `@Module`

Un módulo es un `enum` con funciones estáticas. Cada función es una receta; el decorador dice cuánto vive.

```swift
import DaggerSwift

@MainActor            // si tus objetos son @Observable de SwiftUI
@Module
enum AppModule {
    @Singleton static func theme() -> Theme { Theme() }                 // toda la app
    @Singleton static func apiClient() -> any ApiClient { LiveApiClient() }
}

@MainActor
@Module
enum SessionModule {
    /// Candado: si devuelve nil, nada de este subgrafo se construye.
    @Precondition("Se requiere sesión iniciada")
    static func session(auth: AuthStore) -> ActiveSession? { auth.current }

    /// Vive mientras el scope esté abierto; muere al cerrarlo.
    @Scoped static func currentUser(session: ActiveSession, api: any ApiClient) -> CurrentUser {
        CurrentUser(session: session, api: api)
    }
}
```

| Decorador | Vive | Úsalo para |
|---|---|---|
| `@Singleton` | Toda la app | Tema, preferencias, cliente HTTP base |
| `@Scoped` | Mientras el scope esté abierto | Todo lo que depende de la cuenta, del flujo, de la pantalla |
| `@Provider` | Una instancia por petición | View models y casos de uso sin estado compartido |
| `@Precondition` | Se evalúa antes de construir | Sesión, permisos, país activo |
| `@BusinessRule` | Se reevalúa al consultar | Feature flags, variantes A/B |

Los parámetros de una función son sus dependencias: el grafo las resuelve. **El módulo crea el objeto.**
Si devuelve `Algo.shared`, el grafo es decorativo (ver §5).

---

## 2. Declara qué necesita cada cosa: `@Inject`

```swift
@MainActor
@Inject
final class TimelineViewModel {
    let userPreferences: UserPreferences     // lo pide al grafo
    let streamWatcher: StreamWatcher
    var statuses: [Status] = []              // con valor inicial: no se pide al grafo
}
```

La macro genera el `init(userPreferences:streamWatcher:)` limpio (para tests y para construirlo a mano) y el
registro automático: nadie lo registra en ningún módulo; la primera vez que alguien lo pide, el grafo lo
construye con sus dependencias.

Reglas que te ahorran una tarde:

- Si escribes tu propio `init`, la macro usa **sus parámetros**; los que tengan valor por defecto no se piden.
- `final class`: en una clase no final la macro genera `Self(...)`, que exige `required init`.
- Dentro del tipo no uses `.init()` como valor por defecto (`let x: T = .init()`): la macro lo confunde con el
  init del tipo. Escribe `T()`.
- Dependencias del grafo **y** parámetros de la llamada en el mismo `init` (`status:`, `mode:`) no caben en
  `@Inject`: no hay inyección asistida. Ese tipo lo construye quien lo usa, con el `init` normal.

---

## 3. Lista qué existe en cada nivel: `@AppCompose` y `@Compose`

El compositor raíz es la **única** pieza que abre el grafo. Es una lista; el cableado lo genera la macro.

```swift
@MainActor
@Observable                                   // para ponerlo en el Environment de SwiftUI
@AppCompose(AppModule.self)
final class AppCompose {
    // Nivel app: existen siempre. init() los resuelve una vez; si falta uno, init lanza.
    let theme: Theme
    let apiClient: any ApiClient

    // Scope hijo. openSession() lo abre; close() lo cierra. Quien guarda el valor es dueño.
    @Compose(SessionModule.self)
    struct Session {
        let session: ActiveSession            // @Precondition: init lanza si no hay sesión, sin construir nada
        let currentUser: CurrentUser          // @Scoped

        @Compose(EditorModule.self)           // sub-sub-scope: session.openEditor()
        struct Editor { let store: EditorStore }
    }
}
```

Generado por ti: nada. Generado por la macro: `graph`, `init() throws`, `close()`, `openSession()`,
y dentro de `Session`: `init(parent:) throws`, `close()`, `openEditor()`.

---

## 4. La raíz: un solo `catch`, y publicar en la UI

```swift
@main
struct MyApp: App {
    let compose: AppCompose
    @State private var session: AppCompose.Session?

    init() {
        do {
            compose = try AppCompose()        // el ÚNICO do/catch del grafo
        } catch {
            fatalError("Grafo mal armado: \(error)")   // error de programación: dagger-graph lo detecta antes
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(compose.theme)   // las vistas usan @Environment(Theme.self): no saben de DI
                .environment(session?.currentUser)
                .task(id: auth.currentUserID) {
                    session?.close()          // cambio de cuenta: cerrar y reabrir
                    do { session = try compose.openSession() }
                    catch GraphError.unmetPrecondition { session = nil; router.showLogin() }   // estado
                    catch { fatalError("\(error)") }                                           // bug
                }
        }
    }
}
```

Dos familias de errores, dos reacciones, un solo sitio ([COORDINATOR.md](COORDINATOR.md)):

- **Error de programación** (`unregisteredDependency`, `circularDependency`, `scopeNotActive`,
  `mainActorRequired`): es un bug. `dagger-graph` lo detecta antes de compilar; en runtime, detén la app.
- **Error de estado** (`unmetPrecondition`, `scopeClosed`): es navegación. Login, reabrir el flujo.

Las vistas y los view models **no** atrapan `GraphError`. Reciben objetos ya resueltos por `init` o por
`Environment`.

---

## 5. Lo que no debes hacer aunque se pueda

Todo esto compila. Todo esto rompe la resolución explícita.

### 5.1 `container.resolve(T.self)` fuera del compositor

```swift
// ❌ En una vista, un view model, un servicio…
let theme = try container.resolve(Theme.self)
```

Es una **caja mágica**: la vista pide "lo que sea" a un diccionario en runtime. Nadie puede leer en su
firma qué necesita, el compilador no puede comprobarlo, `dagger-graph` no sabe desde qué raíz se pide, y la
pieza se vuelve imposible de construir en un test sin montar el grafo. Es el service locator que la
librería existe para evitar, solo que con otro nombre.

En su lugar: la dependencia va en el `init` (`@Inject`) o llega por `Environment`. `resolve` lo llama
únicamente el código generado por `@AppCompose` / `@Compose`.

### 5.2 Pasar el `ScopeContainer` a una feature

`compose.graph` o `session.graph` existen para la raíz: publicarlos en `\.graphScope` sirve de puente para
que una vista resuelva un `@Inject` sin importar la librería. Si una feature recibe el contenedor y resuelve
de él, estás en 5.1.

### 5.3 `Module.resolve(T.self)` estático

```swift
// ❌
let theme = try AppModule.resolve(Theme.self)
```

Resuelve contra un árbol **escondido** de la librería (`sharedRuntimeScope`), no contra tu `AppCompose`.
Tendrás dos `Theme`, dos `ApiClient`, dos de todo. Esta API existe para scripts y pruebas rápidas, no
para una app con compositor.

### 5.4 `bindInstance(...)` y `provide…(...)` a mano

```swift
// ❌
container.bindInstance(FakeApiClient(), as: (any ApiClient).self)
```

Es registro imperativo: invisible para `dagger-graph`, invisible para quien lee los módulos. Para
intercambiar implementaciones usa un `@Module` alternativo (`FakeApiModule`) y pásalo en el test, o
`@Module(includes:)` con un contrato.

### 5.5 `try?` al resolver

```swift
// ❌
let vm = try? graph.resolve(TimelineViewModel.self)
```

Convierte un bug (binding faltante) en un `nil` silencioso. Si algo puede faltar por estado, es una
`@Precondition` y el compositor lanza `unmetPrecondition`; si falta por programación, debe tronar.

### 5.6 `catch GraphError` en pantallas y view models

Las pantallas no deciden qué hacer cuando falta la sesión: lo decide el coordinador, una vez, en la raíz.
Un `catch` por pantalla multiplica la política de errores por el número de pantallas.

### 5.7 `.shared` dentro de un `@Module`

```swift
// ❌ El grafo no crea nada: registra objetos que se crean solos.
@Singleton static func theme() -> Theme { .shared }
```

Sirve como paso intermedio de una migración (así se hizo en Ice Cubes). No es el destino: mientras exista
`Theme.shared`, cualquiera puede saltarse el grafo, y el scope no controla la vida del objeto.

### 5.8 Un compositor accesible como global

```swift
// ❌
enum AppGraph { static let compose = try! AppCompose() }
```

Si cualquier archivo puede escribir `AppGraph.compose.theme`, el compositor es un service locator con
mayúsculas. El compositor lo **posee** la raíz (`App`, `AppDelegate`, `Coordinator`) y lo publica hacia
abajo por `Environment` o por `init`. Nada hacia arriba.

### 5.9 `@Singleton` para estado de sesión

Un `@Singleton` es inmortal. Si guarda al usuario actual, el siguiente usuario verá los datos del anterior.
Todo lo que dependa de la cuenta va `@Scoped` bajo un `@Compose` que se cierra al cambiar de cuenta.

### 5.10 `@Inject` con `@Published` / `@State` como dependencias

`@Inject` ignora propiedades con valor inicial y las marcadas `@Published`, `@State`, `@Binding`. Si una
dependencia real no tiene valor inicial pero el tipo no la expone en su `init`, no es del grafo: es
estado. Déjala con valor inicial.

---

## 6. Valídalo antes de compilar

```bash
dagger-graph Sources            # bindings faltantes, ciclos, scopes nunca abiertos; exit 1 si hay errores
```

O como build plugin (`+24 ms` por build):

```swift
.target(name: "App", plugins: [.plugin(name: "DaggerGraphBuildPlugin", package: "DaggerGraph")])
```

`dagger-graph` valida por raíz cuando encuentra `ScopeContainer.root(modules:)` literales. Hoy **no**
reconoce `@AppCompose(M.self)` como raíz (pendiente): valida el grafo en global.

---

## 7. Checklist antes de hacer merge

- [ ] Ningún `resolve(` fuera de AppComposition / código generado.
- [ ] Ningún `Module.resolve(` estático ni `bindInstance(`.
- [ ] Ningún `try?` sobre el grafo.
- [ ] `catch GraphError` solo en la raíz o el coordinador.
- [ ] Nada que dependa de la cuenta o del flujo es `@Singleton`.
- [ ] Los módulos crean sus objetos (sin `.shared`), salvo que esté documentado como paso de migración.
- [ ] `dagger-graph` en verde en CI.
