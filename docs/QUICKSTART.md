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

Un módulo es un `enum` con funciones estáticas. Cada función es una receta: sus parámetros son sus
dependencias y el decorador dice cuánto vive. **El módulo crea el objeto.** Si devuelve `Algo.shared`, el
grafo es decorativo (ver §5.7).

| Decorador | Vive | En el compositor se declara como | Úsalo para |
|---|---|---|---|
| `@Singleton` | Toda la app | `let x: T` en `@AppCompose` | Tema, preferencias, cliente HTTP base |
| `@Scoped` | Mientras el scope esté abierto | `let x: T` en un `@Compose` | Lo que depende de la cuenta, del flujo, de la pantalla |
| `@Provider` | Una instancia por petición | `let x: Provider<T>` | View models y casos de uso sin estado compartido |
| `@Precondition` | Se evalúa antes de construir | `let x: T` en el `@Compose` que la exige | Sesión, permisos, país activo |
| `@BusinessRule` | Se reevalúa al consultar | `let x: Provider<T>` | Feature flags, variantes A/B |

La columna del medio es la que importa: un `let` normal se resuelve **una vez, al abrir ese nivel**; un
`Provider<T>` se resuelve **en cada llamada**. Declarar un `@Provider` o un `@BusinessRule` como `let`
compila, pero congela una instancia por scope y pierdes justo lo que el decorador prometía.

Cada decorador, de punta a punta: módulo → compositor → raíz o vista.

### `@Singleton`: existe toda la app

```swift
@MainActor @Module
enum AppModule {
    @Singleton static func theme() -> Theme { Theme() }
}

@MainActor @Observable
@AppCompose(AppModule.self)
final class AppCompose {
    let theme: Theme                                   // se resuelve en init(), una sola vez
}

// Raíz: lo publica. Vista: lo lee. Ninguna de las dos sabe de DI.
RootView().environment(compose.theme)
struct SettingsView: View { @Environment(Theme.self) private var theme }
```

### `@Scoped`: vive y muere con su scope

```swift
@MainActor @Module
enum SessionModule {
    @Scoped static func currentUser(api: any ApiClient) -> CurrentUser { CurrentUser(api: api) }
}

@AppCompose(AppModule.self)
final class AppCompose {
    @Compose(SessionModule.self)
    struct Session {
        let currentUser: CurrentUser                   // una por apertura del scope
    }
}

// Raíz: abre, publica, y al cambiar de cuenta cierra y reabre. La instancia anterior muere.
var session = try compose.openSession()
RootView().environment(session.currentUser)
session.close(); session = try compose.openSession()
```

Si el objeto tiene un socket, un timer o un stream, conforma `ScopeDisposable`: `close()` llama a
`onScopeTeardown()` antes de soltarlo.

### `@Provider`: una instancia por petición

```swift
@MainActor @Module
enum SessionModule {
    @Provider static func composer(user: CurrentUser) -> PostComposerViewModel { PostComposerViewModel(user: user) }
}

@Compose(SessionModule.self)
struct Session {
    let currentUser: CurrentUser
    let postComposer: Provider<PostComposerViewModel>  // fábrica, no instancia
}

// Quien abre la pantalla construye el view model en ese momento, con sus dependencias del scope.
.sheet(isPresented: $showComposer) {
    PostComposerView(viewModel: try! session.postComposer())   // try! solo si el subgrafo no tiene @Precondition
}
```

`Provider<T>` es el `Provider<T>` de Dagger: quien lo recibe no conoce el grafo, solo puede pedir `T`.
Los `@Inject` también se piden así: `let timeline: Provider<TimelineViewModel>`, sin registrarlos en
ningún módulo.

### `@Precondition`: candado del subgrafo

```swift
@MainActor @Module
enum SessionModule {
    @Precondition("Se requiere sesión iniciada")
    static func session(auth: AuthStore) -> ActiveSession? { auth.current }   // nil = bloqueado

    @Scoped static func inbox(session: ActiveSession) -> Inbox { Inbox(session: session) }   // la exige
}

@Compose(SessionModule.self)
struct Session {
    let session: ActiveSession     // init(parent:) lanza unmetPrecondition si es nil, sin construir nada
    let inbox: Inbox
}

// Raíz o coordinador: el único sitio que decide qué hacer cuando falta.
do {
    session = try compose.openSession()
} catch GraphError.unmetPrecondition(_, let reason) {
    router.showLogin(reason: reason)                   // estado: navegación
}
```

Si no quieres bloquear todo el scope, no pongas la precondición en el `@Compose` de sesión: ponla en el
`@Compose` del flujo que la necesita (`Inbox`), y el resto de la sesión abre igual.

### `@BusinessRule`: se reevalúa al consultar

```swift
@MainActor @Module
enum AppModule {
    @Singleton static func flags() -> FeatureFlags { FeatureFlags() }

    @BusinessRule static func layout(flags: FeatureFlags) -> any LayoutStrategy {
        flags.bento ? BentoLayout() : ClassicLayout()
    }
}

@AppCompose(AppModule.self)
final class AppCompose {
    let layout: Provider<any LayoutStrategy>           // cada llamada vuelve a mirar el flag
}

// La vista pide la variante cuando la va a usar; si el flag cambió, cambia la variante. Sin reabrir nada.
let strategy = try compose.layout()
```

Con `let layout: any LayoutStrategy` la variante quedaría fijada al arrancar la app.

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
        let currentUser: CurrentUser          // @Scoped: una por scope
        let timeline: Provider<TimelineViewModel>   // @Provider / @Inject: una por llamada

        @Compose(EditorModule.self)           // sub-sub-scope: session.openEditor()
        struct Editor { let store: EditorStore }
    }
}
```

Generado por ti: nada. Generado por la macro: `graph`, `init() throws`, `close()`, `openSession()`,
y dentro de `Session`: `init(parent:) throws`, `close()`, `openEditor()`, y `timeline` como fábrica.
También `makeGraph()` e `init(graph:)`: abre el grafo sin resolver, haz algo con él (registrar un módulo
falso en un test, instalar el puente de una migración que los `init` heredados aún consultan) y compón.

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

La variante clásica, `AppContainer.shared.resolve()` como valor por defecto de un `init`, es el mismo
problema con un global delante; el linter la cuenta aparte (`locator-resolve`) para medir una migración.

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

### 5.11 Un `@Provider` o un `@BusinessRule` como `let` en el compositor

```swift
// ❌ Compila. Se resuelve una vez al abrir el scope: ya no es "una por petición" ni "se reevalúa".
let composer: PostComposerViewModel
let layout: any LayoutStrategy
```

Declara `Provider<T>`. El `let` normal es para `@Singleton` y `@Scoped`.

---

## 6. Valídalo antes de compilar: `dagger-graph` y su linter

Dos cosas se comprueban en tiempo de compilación, por dos vías:

| Vía | Qué ve | Cómo lo muestra |
|---|---|---|
| Las macros (`@Inject`, `@Module`) | Solo la declaración donde están | Diagnóstico del compilador, sin configurar nada: clase no `final` (error), `.init(` como valor por defecto (warning), `.shared` en un módulo (warning) |
| `dagger-graph` (CLI o build plugin) | Todos los archivos | `archivo:línea:col: error|warning:` en cada build; Xcode lo pinta en el código y un error tumba el build |

### El grafo

```bash
dagger-graph Sources            # bindings faltantes, ciclos, scopes nunca abiertos; exit 1 si hay errores
```

Valida **por raíz de composición**: cada `@AppCompose(M.self)` es una raíz y cada `@Compose(S.self)` un
hijo, igual que `ScopeContainer.root(modules:)` y `makeChildScope(for:)`. Un `let` que ningún módulo de
ese nivel provea, o que viva en un scope que ese nivel nunca abre, es un error en la línea del `let`.

### El linter

```bash
dagger-graph --lint Sources     # además, las reglas de §5
```

O, para que corra siempre (CLI y build plugin), un `dagger-graph.json` en el paquete o en un directorio
padre:

```json
{
  "lint": true,
  "rootFiles": ["App/Main/", "App/Router/AppRegistry.swift"],
  "rules": { "container-in-feature": "error", "dynamic-registration": "off" }
}
```

- `rootFiles`: fragmentos de ruta que cuentan como raíz o coordinador (donde sí va el `catch` de
  `GraphError`). Los archivos que declaran un `@AppCompose` / `@Compose` lo son siempre.
- `rules`: `"error"`, `"warning"` u `"off"` por regla. Los tests (`/Tests/`, `*Tests.swift`) no se lintan.
- Silenciar un sitio: `// dagger-graph: allow <regla> — motivo` en la misma línea o en la anterior.
  `// dagger-graph: allow` sin regla silencia todas las de esa línea.

| Regla | Sección | Por defecto |
|---|---|---|
| `resolve-outside-compositor` | 5.1 | error |
| `locator-resolve` (`X.shared.resolve()`, el locator clásico) | 5.1 | warning |
| `container-in-feature` | 5.2 | warning |
| `module-static-resolve` | 5.3 | error |
| `dynamic-registration` | 5.4 | warning |
| `optional-try` | 5.5 | error |
| `catch-outside-root` | 5.6 | warning |
| `shared-in-module` | 5.7 | warning |
| `static-compositor` | 5.8 | error |
| `inject-non-final`, `inject-dot-init` | 5.10 | error, warning |
| `provider-as-let`, `let-as-provider` | 5.11 | error, warning |

5.9 (`@Singleton` que depende de un scope hijo) la detecta la validación del grafo, con o sin linter.

### Como build plugin

```swift
.target(name: "App", plugins: [.plugin(name: "DaggerGraphBuildPlugin", package: "DaggerGraph")])
```

+24 a 27 ms por build. El plugin lee el mismo `dagger-graph.json`, así que el linter corre en cada build
sin flags.

---

## 7. Checklist antes de hacer merge

- [ ] Ningún `resolve(` fuera de AppComposition / código generado.
- [ ] Ningún `Module.resolve(` estático ni `bindInstance(`.
- [ ] Ningún `try?` sobre el grafo.
- [ ] `catch GraphError` solo en la raíz o el coordinador.
- [ ] Nada que dependa de la cuenta o del flujo es `@Singleton`.
- [ ] Ningún `@Provider` ni `@BusinessRule` declarado como `let` en un compositor (van como `Provider<T>`).
- [ ] Los módulos crean sus objetos (sin `.shared`), salvo que esté documentado como paso de migración.
- [ ] `dagger-graph --lint` en verde en CI (o `"lint": true` en `dagger-graph.json`).
