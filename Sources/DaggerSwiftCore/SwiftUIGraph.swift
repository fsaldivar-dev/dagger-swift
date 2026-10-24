//
//  SwiftUIGraph.swift
//  DaggerSwift
//
//  Created by Saldivar on 16/10/26.
//

#if canImport(SwiftUI)
import Combine
import SwiftUI

/// Objeto retenido por `@StateObject` / `@State` dentro de `GraphScopeView` que garantiza:
/// 1. Que el `ScopeContainer` hijo (ej. `LoansModule`) se cree una sola vez mientras el flujo esté vivo en SwiftUI.
/// 2. Que cuando el flujo salga de la jerarquía de navegación de SwiftUI, `deinit` dispare `teardown()`
///    liberando automáticamente todas las dependencias del módulo en RAM.
@MainActor
public final class ScopeLifecycleHolder: ObservableObject {
    public let container: ScopeContainer

    public init(container: ScopeContainer) {
        self.container = container
    }

    deinit {
        container.teardown()
    }
}

private struct GraphScopeEnvironmentKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: ScopeContainer = ScopeContainer.root()
}

public extension EnvironmentValues {
    /// El `ScopeContainer` activo en la rama actual de la jerarquía de vistas de SwiftUI.
    var graphScope: ScopeContainer {
        get { self[GraphScopeEnvironmentKey.self] }
        set { self[GraphScopeEnvironmentKey.self] = newValue }
    }
}

/// Contenedor declarativo de SwiftUI que abre un `GraphScope` hijo (por ejemplo, `LoansModule.self`),
/// resuelve el grafo para su vista interna sin usar `AnyView`, y destruye automáticamente
/// todas las dependencias locales del módulo cuando la vista sale de pantalla.
///
/// Importante: `DaggerSwift` NO navega. Si una `@Precondition` (ej. `ValidatedSession`) no se cumple,
/// entrega el `GraphError` al bloque `onBlocked` para que tu Coordinator decida qué pantalla mostrar.
@MainActor
public struct GraphScopeView<Scope: GraphScope, Content: View, BlockedView: View>: View {
    @StateObject private var holder: ScopeLifecycleHolder
    private let contentBuilder: @MainActor (ScopeContainer) throws -> Content
    private let blockedBuilder: @MainActor (GraphError) -> BlockedView

    public init(
        scope: Scope.Type,
        parent: ScopeContainer,
        modules: [any GraphModule.Type] = [],
        @ViewBuilder content: @escaping @MainActor (ScopeContainer) throws -> Content,
        @ViewBuilder onBlocked: @escaping @MainActor (GraphError) -> BlockedView
    ) {
        let childContainer = parent.makeChildScope(for: scope, modules: modules)
        self._holder = StateObject(wrappedValue: ScopeLifecycleHolder(container: childContainer))
        self.contentBuilder = content
        self.blockedBuilder = onBlocked
    }

    public var body: some View {
        Group {
            switch evaluateGraph() {
            case .success(let resolvedView):
                resolvedView
                    .environment(\.graphScope, holder.container)
            case .failure(let error):
                blockedBuilder(error)
            }
        }
        .onDisappear {
            // Si la vista raíz del módulo se desmonta definitivamente, el deinit de ScopeLifecycleHolder
            // asegura la limpieza determinista del ScopeContainer.
        }
    }

    private func evaluateGraph() -> Result<Content, GraphError> {
        do {
            let view = try contentBuilder(holder.container)
            return .success(view)
        } catch let graphError as GraphError {
            return .failure(graphError)
        } catch {
            return .failure(.unmetPrecondition(type: String(reflecting: Scope.self), reason: error.localizedDescription))
        }
    }
}
#endif
