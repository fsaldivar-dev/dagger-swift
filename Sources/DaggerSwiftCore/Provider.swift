//
//  Provider.swift
//  DaggerSwift
//
//  Fábrica tipada para nodos `@Provider` y `@BusinessRule` dentro de un compositor (`@AppCompose` / `@Compose`).
//

/// Una dependencia que se construye **cada vez que se pide**, no al abrir el scope.
///
/// Un `let` normal en un `@AppCompose` / `@Compose` se resuelve una sola vez, al abrir ese nivel. Eso es lo
/// que quieres para `@Singleton` y `@Scoped`, y es exactamente lo que NO quieres para un `@Provider`
/// (una instancia por petición: view models, casos de uso) ni para un `@BusinessRule` (se reevalúa al
/// consultar: feature flags). Declara esos como `Provider<T>` y la macro genera la fábrica:
///
/// ```swift
/// @Compose(SessionModule.self)
/// struct Session {
///     let currentUser: CurrentUser                        // @Scoped: una por scope
///     let timeline: Provider<TimelineViewModel>           // @Provider: una por llamada
///     let layout: Provider<any LayoutStrategy>            // @BusinessRule: se reevalúa en cada llamada
/// }
/// let vm = try session.timeline()                          // construye con sus dependencias del grafo
/// ```
/// Es el `Provider<T>` de Dagger: la pieza que recibe la fábrica no conoce el grafo, solo puede pedir `T`.
public struct Provider<T> {
    private let make: () throws -> T

    public init(_ make: @escaping () throws -> T) {
        self.make = make
    }

    /// Construye (o reevalúa) una instancia nueva.
    public func callAsFunction() throws -> T {
        try make()
    }
}
