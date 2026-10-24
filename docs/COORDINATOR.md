# Errores del grafo: un solo `catch`, en el Coordinator

DaggerSwift separa dos familias de errores. Las pantallas, ViewModels y casos de uso **no** hacen
`do/catch` de errores del grafo: los resuelve **quien coordina** (Coordinator / RootComposer), en un solo lugar.

| Error | Qué significa | Dónde se detecta | Qué hace el Coordinator |
|---|---|---|---|
| `circularDependency` | A necesita B y B necesita A | Compilación (`dagger-graph`) | Reportar + pantalla de respaldo |
| `unregisteredDependency` | Nadie provee el tipo en esa raíz | Compilación (`dagger-graph`, por raíz) | Reportar + pantalla de respaldo |
| `scopeNotActive` | Se pide un `@Scoped(X)` sin haber abierto X (`makeChildScope`) | Compilación (`dagger-graph`, por raíz) | Reportar + pantalla de respaldo |
| `mainActorRequired` | Un tipo `@MainActor` pedido desde background | Compilación con el grafo generado; si no, runtime | Reportar + pantalla de respaldo |
| `unmetPrecondition` | Una `@Precondition` devolvió `nil` (sin sesión, sin permiso…) | Runtime (depende del estado) | **Navegar**: login, guardar el deep link pendiente |
| `scopeClosed` | Se pidió algo de un scope ya cerrado (`teardown`) | Runtime (una referencia vieja) | **Navegar**: reabrir el flujo o volver al inicio |

`GraphError.isProgrammerError` es `true` para las cuatro primeras: son bugs que no deberían llegar a runtime.
Si llegan (el plugin no corrió, la lista de módulos no era literal, `bindInstance`…), el runtime es la red de seguridad:

- **Debug** (`ScopeContainer.programmerErrorPolicy = .assertInDebug`, el valor por defecto): `assertionFailure`, truena al desarrollar.
- **Release**: solo se lanza el error; el Coordinator lo reporta y muestra un respaldo en vez de crashear.
- **Tests**: el valor por defecto es `.throwOnly`, porque los tests provocan estos errores a propósito.
- `.trap` hace `fatalError` siempre (útil en el target de desarrollo si usas el XCFramework de release, que no tiene DEBUG).

## El patrón

```swift
@MainActor
final class AppCoordinator {
    private let graph: ScopeContainer
    private let crashReporter: CrashReporting

    func open<Screen>(_ screen: Screen.Type, from scope: ScopeContainer) {
        do {
            let viewModel = try scope.resolve(screen)
            show(viewModel)
        } catch let error as GraphError where error.isProgrammerError {
            // Bug: debió detectarse al compilar. Reportar y no dejar al usuario en una pantalla rota.
            crashReporter.record(error)
            showFallback()
        } catch GraphError.unmetPrecondition {
            // Estado: falta sesión/permiso. Guardar a dónde iba y pedir login.
            pendingDestination = screen
            showLogin()
        } catch GraphError.scopeClosed {
            // Estado: el flujo ya terminó. Volver a abrirlo desde el inicio.
            restartFlow()
        } catch {
            // Errores lanzados por tus propias factories (red, disco…).
            crashReporter.record(error)
            showFallback()
        }
    }
}
```

Reglas:

1. **Un solo `catch` por punto de navegación**, en el Coordinator. Los ViewModels reciben sus dependencias ya resueltas por `init`.
2. **No uses `try?`** para resolver: oculta errores de programación.
3. Si un `catch` de error de programación se dispara en producción, agrega esa raíz a la validación
   (`dagger-graph`, `generate --smoke-tests`): es una raíz que el análisis estático no vio.

## Nota: tipos `@MainActor` en Linux

En plataformas Apple, resolver un tipo `@MainActor` (un `@Inject` o un `@Module @MainActor`) desde código que corre en
el MainActor funciona directo. En Linux el MainActor no corre necesariamente en el hilo principal y Swift no ofrece
una consulta pública de aislamiento que no haga trap, así que ahí usa `try await container.resolveOnMainActor(T.self)`.
