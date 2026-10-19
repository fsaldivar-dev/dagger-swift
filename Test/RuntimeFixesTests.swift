//
//  RuntimeFixesTests.swift
//  Bloque 2 · Correcciones del runtime (MainActor, locks, cachés, precondiciones).
//

import Foundation
import Testing
import DaggerSwift

// MARK: - e. @MainActor @Inject

final class MainActorFixDep: Sendable {
    init() {}
}

@MainActor
@Inject
final class MainActorFixViewModel {
    let dep: MainActorFixDep
}

/// Tipo NO aislado con un miembro @MainActor: antes la macro lo trataba como @MainActor (crash en background).
@Inject
final class MemberIsolatedFixRepository: Sendable {
    @MainActor private var cached: Int = 0
}

@Module
enum MainActorFixModule {
    @Singleton
    static func dep() -> MainActorFixDep { MainActorFixDep() }
}

@Suite("Bloque 2 · Runtime")
struct RuntimeFixesTests {

    @Test("e. @MainActor @Inject desde background lanza mainActorRequired en vez de crashear")
    func mainActorInjectFromBackgroundThrows() async throws {
        let root = ScopeContainer.root(modules: [MainActorFixModule.self])
        let error: GraphError? = await Task.detached {
            do {
                _ = try root.resolve(MainActorFixViewModel.self)
                return nil
            } catch let e as GraphError {
                return e
            } catch {
                return nil
            }
        }.value
        #expect(error == .mainActorRequired(type: String(reflecting: MainActorFixViewModel.self)))

        // La API explícita salta al MainActor y funciona desde background.
        let vm = try await Task.detached { try await root.resolveOnMainActor(MainActorFixViewModel.self) }.value
        #expect(vm.dep === (try root.resolve(MainActorFixDep.self)))
    }

    @Test("e. Un miembro @MainActor no vuelve @MainActor al tipo: se resuelve desde background")
    func memberIsolationDoesNotIsolateType() async throws {
        let root = ScopeContainer.root()
        let ok = await Task.detached { (try? root.resolve(MemberIsolatedFixRepository.self)) != nil }.value
        #expect(ok)
    }
}
