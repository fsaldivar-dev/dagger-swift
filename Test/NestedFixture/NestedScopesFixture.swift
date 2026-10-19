//
//  NestedScopesFixture.swift
//  Fixture de `dagger-graph generate`: scopes anidados (Global → Sesión → Feature) y
//  @Precondition indirecta. El grafo generado vive en Test/NestedFixture/Generated (scripts/generate-graphs.sh).
//

import Foundation
import Testing
import DaggerSwift

enum NestedSessionScope: GraphScope {}
enum NestedFeatureScope: GraphScope {}

final class NestedApiClient: @unchecked Sendable {
    nonisolated(unsafe) static var initCount = 0
    init() { Self.initCount += 1 }
}

final class NestedSessionStore: @unchecked Sendable {
    let api: NestedApiClient
    init(api: NestedApiClient) { self.api = api }
}

struct NestedSession: Precondition {
    let user: String
}

final class NestedAuthState: @unchecked Sendable {
    nonisolated(unsafe) static var user: String?
}

/// Dependencia "pesada" que NO debe construirse si la precondición (indirecta) falla.
@Inject
final class NestedHeavyReport: @unchecked Sendable {
    nonisolated(unsafe) static var initCount = 0
    let store: NestedSessionStore

    init(store: NestedSessionStore) {
        self.store = store
        Self.initCount += 1
    }
}

/// Caso de uso que pide la sesión a través de otro tipo (precondición INDIRECTA, en segundo lugar).
@Inject
final class NestedSessionGate: @unchecked Sendable {
    let session: NestedSession
}

@Inject(scope: NestedFeatureScope.self)
final class NestedFeatureViewModel: @unchecked Sendable {
    let report: NestedHeavyReport
    let gate: NestedSessionGate
}

@Module
enum NestedAppModule {
    @Singleton
    static func api() -> NestedApiClient { NestedApiClient() }

    @Scoped(NestedSessionScope.self)
    static func store(api: NestedApiClient) -> NestedSessionStore { NestedSessionStore(api: api) }

    @Precondition("Se requiere sesión")
    static func session() -> NestedSession? { NestedAuthState.user.map { NestedSession(user: $0) } }
}

/// Raíz que usa la app (y que `dagger-graph generate` convierte en factories directas).
func makeNestedRuntimeGraph() -> ScopeContainer {
    let root = ScopeContainer.root(modules: [NestedAppModule.self])
    let session = root.makeChildScope(for: NestedSessionScope.self)
    _ = session.makeChildScope(for: NestedFeatureScope.self)
    return root
}

@Suite("Grafo generado: scopes anidados y precondiciones indirectas", .serialized)
struct NestedGeneratedGraphTests {

    @Test("Global → Sesión → Feature: cada nivel guarda lo suyo y ve a sus ancestros")
    func nestedScopes() throws {
        NestedAuthState.user = "fsaldivar-dev"
        NestedApiClient.initCount = 0
        let graph = DaggerGraph_NestedAppModule()
        let session = graph.makeNestedSessionScope()
        let featureA = session.makeNestedFeatureScope()
        let featureB = session.makeNestedFeatureScope()

        let vmA1 = try featureA.nestedFeatureViewModel()
        let vmA2 = try featureA.nestedFeatureViewModel()
        let vmB = try featureB.nestedFeatureViewModel()
        let sameInFeature = vmA1 === vmA2
        let distinctFeatures = vmA1 !== vmB
        let sharedSessionStore = vmA1.report.store === vmB.report.store
        #expect(sameInFeature)
        #expect(distinctFeatures)
        #expect(sharedSessionStore)
        #expect(NestedApiClient.initCount == 1)

        // Otra sesión = otro store; el singleton se comparte.
        let otherStore = try graph.makeNestedSessionScope().nestedSessionStore()
        let distinctSessions = otherStore !== vmA1.report.store
        let sharedApi = otherStore.api === vmA1.report.store.api
        #expect(distinctSessions)
        #expect(sharedApi)
    }

    @Test("@Precondition indirecta se evalúa antes de construir la dependencia pesada (0 allocations)")
    func indirectPreconditionFirst() throws {
        NestedAuthState.user = nil
        NestedHeavyReport.initCount = 0
        let feature = DaggerGraph_NestedAppModule().makeNestedSessionScope().makeNestedFeatureScope()
        #expect(throws: GraphError.self) { _ = try feature.nestedFeatureViewModel() }
        #expect(NestedHeavyReport.initCount == 0)

        NestedAuthState.user = "fsaldivar-dev"
        _ = try feature.nestedFeatureViewModel()
        #expect(NestedHeavyReport.initCount == 1)
    }

    @Test("El runtime con la misma raíz se comporta igual (misma precondición indirecta)")
    func runtimeMatches() throws {
        NestedAuthState.user = nil
        NestedHeavyReport.initCount = 0
        let root = ScopeContainer.root(modules: [NestedAppModule.self])
        let feature = root.makeChildScope(for: NestedSessionScope.self).makeChildScope(for: NestedFeatureScope.self)
        #expect(throws: GraphError.self) { _ = try feature.resolve(NestedFeatureViewModel.self) }
        #expect(NestedHeavyReport.initCount == 0)
    }
}
