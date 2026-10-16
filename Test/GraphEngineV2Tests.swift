//
//  GraphEngineV2Tests.swift
//  DaggerSwift
//
//  Created by Saldivar on 16/10/26.
//

import Testing
import DaggerSwift

// MARK: - 1. Nodos de Dominio, Negocio y Precondición para las Pruebas (Cero decoradores dentro de las clases)

protocol V2ApiClient: AnyObject {
    var baseURL: String { get }
}

final class V2ApiClientRealImpl: V2ApiClient {
    nonisolated(unsafe) static var initCount = 0
    let baseURL = "https://api.produccion.com"

    init() {
        Self.initCount += 1
    }
}

final class HeavyUnusedAnalyticsSDK {
    nonisolated(unsafe) static var initCount = 0
    init() {
        Self.initCount += 1
    }
}

final class FeatureFlagService {
    var isSystemBEnabled: Bool = false
    init() {}
}

final class AuthSessionManager {
    var activeToken: String?
    init() {}
}

/// Precondición de negocio: requiere que exista una sesión autenticada.
/// Además, actúa automáticamente como el identificador de `SessionScope`.
struct ValidatedSession: Precondition {
    let userID: String
    let token: String
}

/// Caché que vive en el Scope de la Sesión: debe sobrevivir al cambiar entre módulos,
/// pero morir automáticamente cuando el usuario hace Logout.
final class SessionAccountsCache {
    let session: ValidatedSession
    let api: any V2ApiClient

    init(session: ValidatedSession, api: any V2ApiClient) {
        self.session = session
        self.api = api
    }
}

// MARK: - Evolución Sistema A -> Sistema B (Regla de Negocio / Feature Flag)

protocol LoanInterestCalculator: AnyObject {
    var versionName: String { get }
    func calculateRate() -> Double
}

/// Sistema A (Legacy)
final class LegacyCalculatorA: LoanInterestCalculator {
    let api: any V2ApiClient
    var versionName: String { "Sistema-A" }

    init(api: any V2ApiClient) {
        self.api = api
    }

    func calculateRate() -> Double { 0.15 }
}

/// Sistema B (Nuevo - Reutiliza piezas de A o del Core mientras migra progresivamente)
final class NewCalculatorB: LoanInterestCalculator {
    let legacyFallback: LegacyCalculatorA
    var versionName: String { "Sistema-B(con-base-\(legacyFallback.versionName))" }

    init(legacyFallback: LegacyCalculatorA) {
        self.legacyFallback = legacyFallback
    }

    func calculateRate() -> Double { 0.09 }
}

// MARK: - Módulo Loans (Sus dependencias deben morir al cerrar Loans)

protocol LoansSimulatorRepository: AnyObject {
    var draftAmount: Double { get set }
    var isTaskCancelled: Bool { get }
}

final class LoansSimulatorRepositoryImpl: LoansSimulatorRepository, ScopeDisposable {
    nonisolated(unsafe) static var initCount = 0
    let api: any V2ApiClient
    let session: ValidatedSession
    let accountsCache: SessionAccountsCache
    var draftAmount: Double = 10_000
    private(set) var isTaskCancelled: Bool = false

    init(api: any V2ApiClient, session: ValidatedSession, accountsCache: SessionAccountsCache) {
        Self.initCount += 1
        self.api = api
        self.session = session
        self.accountsCache = accountsCache
    }

    func onScopeTeardown() {
        isTaskCancelled = true
    }
}

final class LoansUseCase {
    let repository: any LoansSimulatorRepository
    let calculator: any LoanInterestCalculator

    // Constructor puro: en Unit Tests se instancia directo con mocks sin tocar DaggerSwift
    init(repository: any LoansSimulatorRepository, calculator: any LoanInterestCalculator) {
        self.repository = repository
        self.calculator = calculator
    }
}

final class LoansViewModel {
    let useCase: LoansUseCase

    init(useCase: LoansUseCase) {
        self.useCase = useCase
    }
}

// MARK: - Definición de Módulos del Grafo (v2)

enum CoreGraphModule: GraphModule {
    static func register(in container: ScopeContainer) {
        // 1. Dominio (@Singleton Lazy): Cero instancias creadas al arrancar la app
        container.provideSingleton((any V2ApiClient).self, factory: V2ApiClientRealImpl.init)
        container.provideSingleton(HeavyUnusedAnalyticsSDK.init)
        container.provideSingleton(FeatureFlagService.init)
        container.provideSingleton(AuthSessionManager.init)

        // 2. Precondición (@Precondition): Valida si existe sesión activa
        container.providePrecondition(
            ValidatedSession.self,
            reasonIfUnmet: "El usuario no ha iniciado sesión"
        ) { (authManager: AuthSessionManager) in
            guard let token = authManager.activeToken else { return nil }
            return ValidatedSession(userID: "user-42", token: token)
        }

        // 3. Dependencia atada al Scope de la Precondición (ValidatedSession)
        container.provideScoped(in: ValidatedSession.self, SessionAccountsCache.init)
    }
}

enum LoansModule: GraphModule {
    static func register(in container: ScopeContainer) {
        // 1. Dependencia Scoped a LoansModule (usa automáticamente LoansModule.scopeID y muere al cerrar Loans)
        container.provideScoped((any LoansSimulatorRepository).self, factory: LoansSimulatorRepositoryImpl.init)

        // 2. Nodos de evolución Sistema A -> Sistema B gobernados por Regla de Negocio (Feature Flag)
        container.provide(LegacyCalculatorA.init)
        container.provide(NewCalculatorB.init)

        container.provideBusinessRule((any LoanInterestCalculator).self) {
            (flags: FeatureFlagService, systemA: LegacyCalculatorA, systemB: NewCalculatorB) -> any LoanInterestCalculator in
            flags.isSystemBEnabled ? systemB : systemA
        }

        // 3. Providers con auto-resolución por Parameter Packs (pasando únicamente .init)
        container.provide(LoansUseCase.init)
        container.provide(LoansViewModel.init)
    }
}

// MARK: - Suite de Pruebas de DaggerSwift v2

@Suite("Dagger 2 - Graph Engine, Scopes, Preconditions & Memory Lifecycle", .serialized)
@MainActor
struct DaggerV2GraphTests {

    @Test("1. Launcher Ligero: Registrar el grafo completo instancia 0 objetos al arrancar")
    func testZeroCostLazyLauncher() {
        V2ApiClientRealImpl.initCount = 0
        HeavyUnusedAnalyticsSDK.initCount = 0
        LoansSimulatorRepositoryImpl.initCount = 0

        let root = ScopeContainer.root(modules: [CoreGraphModule.self])

        // Al arrancar la app, ninguna dependencia se ha instanciado en memoria
        #expect(root.activeInstanceCount == 0)
        #expect(V2ApiClientRealImpl.initCount == 0)
        #expect(HeavyUnusedAnalyticsSDK.initCount == 0)
    }

    @Test("2. Deep Link sin Sesión: @Precondition detiene el grafo antes de construir el módulo")
    func testDeepLinkBlockedByUnmetSessionPrecondition() throws {
        V2ApiClientRealImpl.initCount = 0
        LoansSimulatorRepositoryImpl.initCount = 0

        let root = ScopeContainer.root(modules: [CoreGraphModule.self])
        let sessionScope = root.makeChildScope(for: ValidatedSession.self)
        let loansScope = sessionScope.makeChildScope(for: LoansModule.self)

        // Intentamos abrir Loans desde un Deep Link con la app cerrada (activeToken == nil)
        #expect(throws: GraphError.unmetPrecondition(
            type: String(reflecting: ValidatedSession.self),
            reason: "El usuario no ha iniciado sesión"
        )) {
            _ = try loansScope.resolve(LoansViewModel.self)
        }

        // LoansSimulatorRepository jamás llegó a construirse porque faltaba la precondición
        #expect(LoansSimulatorRepositoryImpl.initCount == 0)
        // HeavyUnusedAnalyticsSDK jamás se tocó
        #expect(HeavyUnusedAnalyticsSDK.initCount == 0)
    }

    @Test("3. Auto-resolución en cascada y Reglas de Negocio (Migración Sistema A -> Sistema B)")
    func testCascadingResolutionAndBusinessRuleMigration() throws {
        let root = ScopeContainer.root(modules: [CoreGraphModule.self])

        // Simulamos que el flujo de Auth ya validó la sesión
        let authManager = try root.resolve(AuthSessionManager.self)
        authManager.activeToken = "jwt-token-valido"

        let sessionScope = root.makeChildScope(for: ValidatedSession.self)
        let loansScope = sessionScope.makeChildScope(for: LoansModule.self)

        // Con Feature Flag apagado -> El grafo resuelve Sistema A
        let vmA = try loansScope.resolve(LoansViewModel.self)
        #expect(vmA.useCase.calculator.versionName == "Sistema-A")
        #expect(vmA.useCase.calculator.calculateRate() == 0.15)

        // Encendemos el Feature Flag en caliente -> El grafo bifurca a Sistema B (que compone a A)
        let flags = try root.resolve(FeatureFlagService.self)
        flags.isSystemBEnabled = true

        let vmB = try loansScope.resolve(LoansViewModel.self)
        #expect(vmB.useCase.calculator.versionName == "Sistema-B(con-base-Sistema-A)")
        #expect(vmB.useCase.calculator.calculateRate() == 0.09)

        // Ambos ViewModels dentro de Loans comparten la misma instancia @Scoped de LoansSimulatorRepository
        #expect(vmA.useCase.repository === vmB.useCase.repository)
    }

    @Test("4. Ciclo de Vida de Scopes: Al cerrar Loans mueren sus dependencias en RAM, pero Session y Global sobreviven")
    func testLoansScopeMemoryDeallocationOnClose() throws {
        let root = ScopeContainer.root(modules: [CoreGraphModule.self])
        try root.resolve(AuthSessionManager.self).activeToken = "jwt-token-valido"

        let sessionScope = root.makeChildScope(for: ValidatedSession.self)
        let loansScope = sessionScope.makeChildScope(for: LoansModule.self)

        // Referencias weak para comprobar con ARC que los objetos realmente mueren de la RAM
        weak var weakGlobalApi: AnyObject?
        weak var weakSessionCache: SessionAccountsCache?
        weak var weakLoansRepo: LoansSimulatorRepositoryImpl?
        var repoRefForCancellationCheck: LoansSimulatorRepositoryImpl?

        do {
            let vm = try loansScope.resolve(LoansViewModel.self)
            let repo = vm.useCase.repository as? LoansSimulatorRepositoryImpl
            repo?.draftAmount = 55_000

            weakLoansRepo = repo
            weakSessionCache = repo?.accountsCache
            weakGlobalApi = repo?.api
            repoRefForCancellationCheck = repo
            #expect(repoRefForCancellationCheck?.isTaskCancelled == false)
            repoRefForCancellationCheck = nil

            #expect(weakLoansRepo != nil)
            #expect(weakSessionCache != nil)
            #expect(weakGlobalApi != nil)
        }

        // PASO A: El usuario cierra el módulo Loans -> Ejecutamos teardown() de loansScope
        let leaksInLoans = loansScope.teardown()

        // 1. Cero memory leaks reportados por el auditor
        #expect(leaksInLoans.isEmpty)
        // 2. ¡LoansSimulatorRepository murió completamente de la memoria RAM!
        #expect(weakLoansRepo == nil)
        // 3. Pero la caché de Sesión y el ApiClient Global siguen vivos
        #expect(weakSessionCache != nil)
        #expect(weakGlobalApi != nil)

        // PASO B: El usuario cierra Sesión (Logout) -> Ejecutamos teardown() de sessionScope
        let leaksInSession = sessionScope.teardown()
        #expect(leaksInSession.isEmpty)
        // ¡Ahora SessionAccountsCache también murió de la memoria RAM!
        #expect(weakSessionCache == nil)
        // Y el Singleton Global (ApiClient) sigue vivo para la pantalla de Login
        #expect(weakGlobalApi != nil)
    }

    @Test("5. Auditoría de Retain Cycles: teardown() detecta si un desarrollador dejó una fuga de memoria")
    func testLeakDetectorCatchesRetainCycle() throws {
        final class LeakyLoansService {
            var selfRetainCycle: (() -> Void)?
            init() {
                // Retain cycle intencional (captura fuerte de self)
                self.selfRetainCycle = { _ = self }
            }
        }

        let root = ScopeContainer.root()
        let loansScope = root.makeChildScope(for: LoansModule.self)
        loansScope.provideScoped(LeakyLoansService.init)

        _ = try loansScope.resolve(LeakyLoansService.self)

        // Al cerrar el Scope, el auditor detecta que LeakyLoansService no murió por culpa del retain cycle
        let leakedTypes = loansScope.teardown()
        #expect(leakedTypes.count == 1)
        #expect(leakedTypes.first?.contains("LeakyLoansService") == true)
    }

    @Test("6. Detección de Ciclos Infinitos (A -> B -> A)")
    func testCircularDependencyDetection() {
        final class NodeA { init(b: NodeB) {} }
        final class NodeB { init(a: NodeA) {} }

        let root = ScopeContainer.root()
        root.provide(NodeA.init)
        root.provide(NodeB.init)

        #expect(throws: GraphError.self) {
            _ = try root.resolve(NodeA.self)
        }
    }

    @Test("7. Regla de Oro de Scopes: No se puede resolver una dependencia de un Scope que no está activo hacia arriba")
    func testScopeHierarchyRuleEnforcement() throws {
        let root = ScopeContainer.root(modules: [CoreGraphModule.self])
        try root.resolve(AuthSessionManager.self).activeToken = "jwt-token-valido"

        // Intentamos resolver SessionAccountsCache (que requiere el Scope de ValidatedSession)
        // directamente desde GlobalScope sin haber abierto la caja de ValidatedSession:
        #expect(throws: GraphError.scopeNotActive(
            requestedScope: ValidatedSession.scopeID,
            currentScope: GlobalScope.scopeID,
            dependencyType: String(reflecting: SessionAccountsCache.self)
        )) {
            _ = try root.resolve(SessionAccountsCache.self)
        }
    }

    @Test("8. Soporte UIKit / AppKit / Coordinator: autoTeardown destruye el Scope cuando el controlador sale de memoria")
    func testUIKitViewControllerAndCoordinatorAutoTeardown() throws {
        // Simula un UIViewController o Coordinator de UIKit dueño de un flujo
        final class SimulatedUIKitLoansViewController {}

        let root = ScopeContainer.root(modules: [CoreGraphModule.self])
        try root.resolve(AuthSessionManager.self).activeToken = "jwt-token-valido"
        let sessionScope = root.makeChildScope(for: ValidatedSession.self)
        let loansScope = sessionScope.makeChildScope(for: LoansModule.self)

        weak var weakLoansRepo: LoansSimulatorRepositoryImpl?
        var viewController: SimulatedUIKitLoansViewController? = SimulatedUIKitLoansViewController()

        if let vc = viewController {
            // Atamos la vida del Scope de Loans al UIViewController / Coordinator
            loansScope.autoTeardown(whenDeallocated: vc)
            let vm = try loansScope.resolve(LoansViewModel.self)
            weakLoansRepo = vm.useCase.repository as? LoansSimulatorRepositoryImpl
            #expect(weakLoansRepo != nil)
            #expect(loansScope.isTornDown == false)
        }

        // El usuario hace 'pop' del UIViewController en UIKit -> ARC libera el controlador
        viewController = nil

        // Sin llamar a teardown() manualmente, el Scope de Loans se cerró solo y liberó sus dependencias
        #expect(loansScope.isTornDown == true)
        #expect(weakLoansRepo == nil)
    }

    @Test("9. Soporte Background / CLI / Actors: Resolución concurrente fuera del MainActor")
    func testBackgroundThreadAndActorResolution() async throws {
        let root = ScopeContainer.root(modules: [CoreGraphModule.self])
        try root.resolve(AuthSessionManager.self).activeToken = "jwt-token-valido"
        let sessionScope = root.makeChildScope(for: ValidatedSession.self)

        // Resolvemos concurrentemente desde un hilo de background (Task.detached) sin @MainActor
        let tokenFromBackground = try await Task.detached {
            let loansScope = sessionScope.makeChildScope(for: LoansModule.self)
            let vm = try loansScope.resolve(LoansViewModel.self)
            let repo = vm.useCase.repository as? LoansSimulatorRepositoryImpl
            let token = repo?.session.token
            loansScope.teardown()
            return token
        }.value

        #expect(tokenFromBackground == "jwt-token-valido")
    }
}
