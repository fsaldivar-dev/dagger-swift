// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import Foundation
import Testing

/// Resuelve `type` y registra un Issue solo si es un error de programación (debió detectarse al compilar).
private func smokeResolve<T>(_ container: ScopeContainer, _ type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) {
    do {
        _ = try container.resolve(type)
    } catch let error as GraphError where !error.isProgrammerError {
        // Estado (p. ej. @Precondition sin sesión): válido en un test de humo.
    } catch {
        Issue.record("\(String(reflecting: type)): \(error)", sourceLocation: sourceLocation)
    }
}

@Suite("Humo: cada raíz resuelve con el runtime (generado por dagger-graph)")
struct DaggerGraphSmokeTests {
    @Test("Humo · [BenchModuleV0_1]")
    func smoke_DaggerGraph_BenchModuleV0_1() {
        let root = ScopeContainer.root(modules: [BenchModuleV0_1.self])
        let benchFeatureScopeBox = root.makeChildScope(for: BenchFeatureScope.self)
        smokeResolve(root, (any BenchApiClientProtocol).self)
        smokeResolve(root, BenchRepositoryImpl.self)
        smokeResolve(benchFeatureScopeBox, (any BenchRepositoryProtocol).self)
        smokeResolve(benchFeatureScopeBox, BenchUseCase.self)
    }

    @Test("Humo · [BenchModuleV2]")
    func smoke_DaggerGraph_BenchModuleV2() {
        let root = ScopeContainer.root(modules: [BenchModuleV2.self])
        let benchFeatureScopeBox = root.makeChildScope(for: BenchFeatureScope.self)
        smokeResolve(root, (any BenchApiClientProtocol).self)
        smokeResolve(root, BenchRepositoryImpl.self)
        smokeResolve(root, BenchSessionPrecondition.self)
        smokeResolve(benchFeatureScopeBox, BenchProtectedInteractor.self)
        smokeResolve(benchFeatureScopeBox, (any BenchRepositoryProtocol).self)
        smokeResolve(benchFeatureScopeBox, BenchUseCase.self)
    }

    @Test("Humo · [BenchModuleV1]")
    func smoke_DaggerGraph_BenchModuleV1() {
        let root = ScopeContainer.root(modules: [BenchModuleV1.self])
        let benchFeatureScopeBox = root.makeChildScope(for: BenchFeatureScope.self)
        smokeResolve(root, (any BenchApiClientProtocol).self)
        smokeResolve(root, BenchRepositoryImpl.self)
        smokeResolve(benchFeatureScopeBox, (any BenchRepositoryProtocol).self)
        smokeResolve(benchFeatureScopeBox, BenchUseCase.self)
    }
}
