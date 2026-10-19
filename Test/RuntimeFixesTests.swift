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

// MARK: - f. Factories fuera del lock

final class SlowFixService: @unchecked Sendable {
    nonisolated(unsafe) static var initCount = 0
    init() { Self.initCount += 1 }
}
/// Tipo exclusivo del test de "una sola construcción" (los tests corren en paralelo: no compartir contadores).
final class OnceFixService: @unchecked Sendable {
    nonisolated(unsafe) static var initCount = 0
    init() { Self.initCount += 1 }
}
final class FastFixService: @unchecked Sendable {
    init() {}
}
final class CycleFixA: @unchecked Sendable { init() {} }
final class CycleFixB: @unchecked Sendable { init() {} }

// MARK: - h. Precondiciones antes de construir

final class HeavyFixDependency: @unchecked Sendable {
    nonisolated(unsafe) static var initCount = 0
    init() { Self.initCount += 1 }
}

struct FixSession: Precondition {
    let user: String
}

@Inject
final class ProtectedFixInteractor: @unchecked Sendable {
    // La precondición va en SEGUNDO lugar a propósito.
    let heavy: HeavyFixDependency
    let session: FixSession
}

final class FixAuthState: @unchecked Sendable {
    var user: String?
    nonisolated(unsafe) static var validatorCalls = 0
}

extension RuntimeFixesTests {

    @Test("f. Una factory lenta NO bloquea resoluciones no relacionadas en otros hilos")
    func slowFactoryDoesNotSerializeUnrelatedResolutions() throws {
        let root = ScopeContainer.root()
        let started = DispatchSemaphore(value: 0)
        let otherDone = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var sawOtherWhileBuilding = false

        root.provideSingleton(SlowFixService.self) { () -> SlowFixService in
            started.signal()
            // Con el lock global tomado, el otro hilo no podía avanzar: esto expiraba.
            sawOtherWhileBuilding = otherDone.wait(timeout: .now() + 2) == .success
            return SlowFixService()
        }
        root.provideSingleton(FastFixService.self) { FastFixService() }

        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) { _ = try? root.resolve(SlowFixService.self) }
        started.wait()
        DispatchQueue.global().async(group: group) {
            _ = try? root.resolve(FastFixService.self)
            otherDone.signal()
        }
        #expect(group.wait(timeout: .now() + 5) == .success)
        #expect(sawOtherWhileBuilding)
    }

    @Test("f. @Singleton concurrente se construye exactamente una vez (doble verificación)")
    func concurrentSingletonIsBuiltOnce() throws {
        OnceFixService.initCount = 0
        let root = ScopeContainer.root()
        root.provideSingleton(OnceFixService.self) { () -> OnceFixService in
            Thread.sleep(forTimeInterval: 0.05)
            return OnceFixService()
        }
        let lock = NSLock()
        nonisolated(unsafe) var ids = Set<ObjectIdentifier>()
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            let s = try! root.resolve(OnceFixService.self)
            lock.lock(); ids.insert(ObjectIdentifier(s)); lock.unlock()
        }
        #expect(OnceFixService.initCount == 1)
        #expect(ids.count == 1)
    }

    @Test("f. Ciclo entre hilos (A→B en un hilo, B→A en otro) lanza circularDependency, no deadlock")
    func crossThreadCycleThrowsInsteadOfDeadlocking() throws {
        let root = ScopeContainer.root()
        let aStarted = DispatchSemaphore(value: 0)
        let bStarted = DispatchSemaphore(value: 0)
        root.provideSingleton(CycleFixA.self) { () throws -> CycleFixA in
            aStarted.signal()
            _ = bStarted.wait(timeout: .now() + 1)
            _ = try root.resolve(CycleFixB.self)
            return CycleFixA()
        }
        root.provideSingleton(CycleFixB.self) { () throws -> CycleFixB in
            bStarted.signal()
            _ = aStarted.wait(timeout: .now() + 1)
            _ = try root.resolve(CycleFixA.self)
            return CycleFixB()
        }
        let group = DispatchGroup()
        let lock = NSLock()
        nonisolated(unsafe) var errors: [Error] = []
        for work in [{ _ = try root.resolve(CycleFixA.self) }, { _ = try root.resolve(CycleFixB.self) }] {
            DispatchQueue.global().async(group: group) {
                do { try work() } catch { lock.lock(); errors.append(error); lock.unlock() }
            }
        }
        #expect(group.wait(timeout: .now() + 5) == .success)
        #expect(errors.count == 2)
        #expect(errors.allSatisfy { if case GraphError.circularDependency = $0 { true } else { false } })
    }

    // MARK: g

    @Test("g. Un ancestro que registra después invalida la caché de recetas de los nietos")
    func ancestorRegistrationInvalidatesDescendantCaches() throws {
        enum ChildFixScope: GraphScope {}
        enum GrandchildFixScope: GraphScope {}
        let root = ScopeContainer.root()
        root.provide(String.self) { "root" }
        let child = root.makeChildScope(for: ChildFixScope.self)
        let grandchild = child.makeChildScope(for: GrandchildFixScope.self)
        #expect(try grandchild.resolve(String.self) == "root")

        child.provide(String.self) { "child" }
        #expect(try grandchild.resolve(String.self) == "child")
    }

    // MARK: h

    @Test("h. @Precondition en segundo parámetro se evalúa ANTES de construir el primero (0 allocations)")
    func preconditionIsEvaluatedBeforeAnyDependency() throws {
        HeavyFixDependency.initCount = 0
        FixAuthState.validatorCalls = 0
        let auth = FixAuthState()
        let root = ScopeContainer.root()
        root.provide(HeavyFixDependency.self) { HeavyFixDependency() }
        root.providePrecondition(FixSession.self, reasonIfUnmet: "sin sesión") { () -> FixSession? in
            FixAuthState.validatorCalls += 1
            return auth.user.map { FixSession(user: $0) }
        }

        #expect(throws: GraphError.unmetPrecondition(type: String(reflecting: FixSession.self), reason: "sin sesión")) {
            _ = try root.resolve(ProtectedFixInteractor.self)
        }
        #expect(HeavyFixDependency.initCount == 0)

        auth.user = "fsaldivar-dev"
        FixAuthState.validatorCalls = 0
        let interactor = try root.resolve(ProtectedFixInteractor.self)
        #expect(interactor.session.user == "fsaldivar-dev")
        #expect(HeavyFixDependency.initCount == 1)
        // El valor evaluado por adelantado se reutiliza: el validador corre una sola vez por resolución.
        #expect(FixAuthState.validatorCalls == 1)
    }
}

// MARK: - Errores de programación vs. estado

enum ClosedFixScope: GraphScope {}
final class ClosedFixService: @unchecked Sendable { init() {} }

extension RuntimeFixesTests {

    @Test("Errores: isProgrammerError separa bugs (compilación) de estado (Coordinator)")
    func programmerErrorClassification() {
        let scope = GlobalScope.scopeID
        #expect(GraphError.circularDependency(chain: []).isProgrammerError)
        #expect(GraphError.unregisteredDependency(type: "X", searchedFromScope: scope).isProgrammerError)
        #expect(GraphError.scopeNotActive(requestedScope: scope, currentScope: scope, dependencyType: "X").isProgrammerError)
        #expect(GraphError.mainActorRequired(type: "X").isProgrammerError)
        #expect(!GraphError.unmetPrecondition(type: "X", reason: "").isProgrammerError)
        #expect(!GraphError.scopeClosed(scope: scope, dependencyType: "X").isProgrammerError)
    }

    @Test("Errores: pedir algo de un scope ya cerrado es scopeClosed (estado), no scopeNotActive")
    func closedScopeIsStateError() throws {
        let root = ScopeContainer.root()
        let child = root.makeChildScope(for: ClosedFixScope.self)
        child.provideScoped(in: ClosedFixScope.self, ClosedFixService.self) { ClosedFixService() }
        _ = try child.resolve(ClosedFixService.self)
        child.teardown()
        #expect(throws: GraphError.scopeClosed(scope: ClosedFixScope.scopeID, dependencyType: String(reflecting: ClosedFixService.self))) {
            _ = try child.resolve(ClosedFixService.self)
        }
    }

    @Test("Errores: dentro de tests la política por defecto es throwOnly (los tests provocan errores a propósito)")
    func defaultPolicyInsideTests() {
        #expect(ScopeContainer.programmerErrorPolicy == .throwOnly)
    }
}
