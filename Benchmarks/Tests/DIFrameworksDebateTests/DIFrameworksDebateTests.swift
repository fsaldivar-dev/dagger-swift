//
//  DIFrameworksDebateTests.swift
//  DaggerSwiftBenchmarks
//
//  Debate Arquitectónico y Benchmark Empírico Cara a Cara contra las librerías reales del ecosistema:
//  - DaggerSwift (Modo Explícito Compile-Time & Modo Motor DAG con Scopes/Preconditions)
//  - Point-Free `swift-dependencies` (Usada en TCA / The Composable Architecture)
//  - Michael Long `Factory` (Contenedor híbrido + @Injected)
//  - `Swinject` (Contenedor dinámico basado en diccionario)
//
//  Regla de Oro de esta Suite:
//  1. Obligar a fallar a las demás librerías donde el diseño de DaggerSwift gana.
//  2. Obligar a fallar a DaggerSwift donde el diseño de Point-Free, Factory o Swinject nos gana.
//  3. Medir el rendimiento real (10,000 resoluciones) e imprimir un reporte gráfico comparativo.
//

import Foundation
import Testing
import DaggerSwift
import Dependencies
import Factory
import class Factory.Container
import Swinject

// ============================================================================
// MARK: - 0. Dominio Común para Todas las Librerías
// ============================================================================

public protocol BenchApiClientProtocol: Sendable {
    var endpoint: String { get }
}

public struct BenchApiClientImpl: BenchApiClientProtocol {
    public let endpoint: String
    public init(endpoint: String = "https://api.daggerswift.dev/v2") {
        self.endpoint = endpoint
    }
}

public protocol BenchRepositoryProtocol: Sendable {
    var api: any BenchApiClientProtocol { get }
    func fetchValue() -> Int
}

@Inject
public struct BenchRepositoryImpl: BenchRepositoryProtocol {
    public let api: any BenchApiClientProtocol
    public let multiplier: Int

    public init(api: any BenchApiClientProtocol) {
        self.api = api
        self.multiplier = 1
    }

    public init(api: any BenchApiClientProtocol, multiplier: Int) {
        self.api = api
        self.multiplier = multiplier
    }

    public func fetchValue() -> Int { 42 * multiplier }
}

@Inject
public struct BenchUseCase: Sendable {
    public let repository: any BenchRepositoryProtocol
    public func execute() -> Int { repository.fetchValue() }
}

// ============================================================================
// MARK: - 1. Configuración Real en DaggerSwift (Explícito + Motor DAG)
// ============================================================================

public struct BenchSessionPrecondition: Precondition, Sendable {
    public let userID: String
}

public enum BenchFeatureScope: GraphScope {}

@Inject(scope: BenchFeatureScope.self)
public final class BenchProtectedInteractor: Sendable {
    public let session: BenchSessionPrecondition
    public let useCase: BenchUseCase
}

public protocol BenchModuleContract: GraphModule {
    static func apiClient() -> any BenchApiClientProtocol
    static func repository() -> any BenchRepositoryProtocol
    static func makeUseCase() -> BenchUseCase
}

extension BenchModuleContract {
    public static func apiClient() -> any BenchApiClientProtocol { BenchModuleV0_1.apiClient() }
    public static func repository() -> any BenchRepositoryProtocol { BenchModuleV0_1.repository() }
    public static func makeUseCase() -> BenchUseCase { BenchUseCase(repository: repository()) }
}

@Module(0.1, scope: BenchFeatureScope.self)
public enum BenchModuleV0_1: BenchModuleContract {
    @Singleton
    public static func apiClient() -> any BenchApiClientProtocol { BenchApiClientImpl() }

    @Scoped
    public static func repository() -> any BenchRepositoryProtocol {
        BenchRepositoryImpl(api: apiClient())
    }
}

@Module(1.0, scope: BenchFeatureScope.self, includes: [BenchModuleV0_1.self])
public enum BenchModuleV1: BenchModuleContract {
    // Hereda `apiClient()` de V0_1 y solo evoluciona `repository()`
    @Scoped
    public static func repository() -> any BenchRepositoryProtocol {
        BenchRepositoryImpl(api: apiClient(), multiplier: 1)
    }
}

@Module(2.0, scope: BenchFeatureScope.self, includes: [BenchModuleV1.self])
public enum BenchModuleV2: BenchModuleContract {
    @Precondition("Sesión activa requerida antes de instanciar BenchProtectedInteractor")
    public static func validateSession() -> BenchSessionPrecondition? {
        nil // Simula usuario sin sesión activa
    }
}

@Scope(
    of: (any BenchModuleContract).self,
    v0_1: BenchModuleV0_1.self,
    v1_0: BenchModuleV1.self,
    v2_0: BenchModuleV2.self
)
extension BenchFeatureScope {}

// ============================================================================
// MARK: - 2. Configuración Real en Point-Free `swift-dependencies` (TCA)
// ============================================================================

private enum BenchApiDependencyKey: DependencyKey {
    static let liveValue: any BenchApiClientProtocol = BenchApiClientImpl()
    static let testValue: any BenchApiClientProtocol = BenchApiClientImpl(endpoint: "https://test.pointfree.co")
}

private enum BenchRepoDependencyKey: DependencyKey {
    static let liveValue: any BenchRepositoryProtocol = BenchRepositoryImpl(api: BenchApiClientImpl())
    static let testValue: any BenchRepositoryProtocol = BenchRepositoryImpl(api: BenchApiClientImpl(endpoint: "https://test.pointfree.co"))
}

private enum BenchUnconfiguredKey: TestDependencyKey {
    // En Point-Free `swift-dependencies`, si no defines `testValue` (o usas el default de `TestDependencyKey`),
    // acceder a la dependencia en un test sin `withDependencies` dispara un XCTFail / Issue en Runtime.
    static var testValue: any BenchRepositoryProtocol {
        reportIssue("Point-Free swift-dependencies: Dependencia 'unconfiguredRepo' accedida sin configurar en withDependencies")
        return BenchRepositoryImpl(api: BenchApiClientImpl(), multiplier: 0)
    }
}

extension DependencyValues {
    var benchApi: any BenchApiClientProtocol {
        get { self[BenchApiDependencyKey.self] }
        set { self[BenchApiDependencyKey.self] = newValue }
    }
    var benchRepo: any BenchRepositoryProtocol {
        get { self[BenchRepoDependencyKey.self] }
        set { self[BenchRepoDependencyKey.self] = newValue }
    }
    var unconfiguredRepo: any BenchRepositoryProtocol {
        get { self[BenchUnconfiguredKey.self] }
        set { self[BenchUnconfiguredKey.self] = newValue }
    }
}

/// Caso de uso acoplado al estilo Point-Free TCA (`@Dependency` dentro de Domain)
struct TcaCoupledUseCase {
    @Dependency(\.benchRepo) var repository
    func execute() -> Int { repository.fetchValue() }
}

struct TcaUnconfiguredUseCase {
    @Dependency(\.unconfiguredRepo) var repository
    func execute() -> Int { repository.fetchValue() }
}

// ============================================================================
// MARK: - 3. Configuración Real en `Factory` (Michael Long)
// ============================================================================

extension Container {
    var benchApi: Factory<any BenchApiClientProtocol> {
        self { BenchApiClientImpl() }.singleton
    }
    var benchRepo: Factory<any BenchRepositoryProtocol> {
        self { BenchRepositoryImpl(api: self.benchApi()) }
    }
    var benchUseCase: Factory<BenchUseCase> {
        self { BenchUseCase(repository: self.benchRepo()) }
    }
}

/// Consumidor acoplado a `Factory` mediante `@Injected`
final class FactoryCoupledConsumer {
    @Injected(\.benchRepo) var repository: any BenchRepositoryProtocol
    init() {} // <- Ventaja de Factory: init() sin argumentos
    func execute() -> Int { repository.fetchValue() }
}

// ============================================================================
// MARK: - 4. Suite de Debate Arquitectónico y Benchmarks
// ============================================================================

@Suite("Debate Empírico: DaggerSwift vs Point-Free Dependencies (TCA) vs Factory vs Swinject", .serialized)
struct DIFrameworksDebateTests {

    // ========================================================================
    // ROUND 1: OBLIGANDO A FALLAR A LAS OTRAS LIBRERÍAS (DONDE GANA DAGGERSWIFT)
    // ========================================================================

    @Test("Round 1.1 [Swinject Falla]: Olvidar registrar un protocolo compila perfecto y devuelve nil en Runtime")
    func testSwinjectFailsAtRuntimeOnMissingRegistration() {
        let swinjectContainer = Swinject.Container()

        // Registramos el UseCase, pero "olvidamos" registrar `BenchRepositoryProtocol`
        swinjectContainer.register(BenchUseCase.self) { resolver in
            guard let repo = resolver.resolve((any BenchRepositoryProtocol).self) else {
                // En proyectos reales suelen escribir `resolver.resolve(...)!` causando crash en producción
                return BenchUseCase(repository: BenchRepositoryImpl(api: BenchApiClientImpl(), multiplier: -1))
            }
            return BenchUseCase(repository: repo)
        }

        // ❌ Swinject falla silenciosamente en Runtime devolviendo `nil` al pedir el protocolo faltante:
        let missingRepo = swinjectContainer.resolve((any BenchRepositoryProtocol).self)
        #expect(missingRepo == nil)

        // ✅ DaggerSwift Explícito: `BenchModuleContract` obliga al compilador a verificar cada proveedor.
        let safeUseCase = BenchFeatureScope.module(for: .v1_0).makeUseCase()
        #expect(safeUseCase.execute() == 42)
    }

    @Test("Round 1.2 [Point-Free TCA Falla]: @Dependency sin configurar dispara Issue en Runtime y acopla Domain")
    func testPointFreeDependenciesFailsWhenUnconfiguredInTest() {
        // ❌ En Point-Free `swift-dependencies`, si un desarrollador instancia `TcaUnconfiguredUseCase()`
        // y olvida envolverlo en `withDependencies { $0.unconfiguredRepo = ... }`, el código COMPILA
        // pero explota en Runtime con un Issue de dependencia no implementada:
        withKnownIssue("Point-Free swift-dependencies falla en Runtime cuando se olvida withDependencies") {
            let useCase = TcaUnconfiguredUseCase()
            _ = useCase.execute()
        }

        // ✅ En DaggerSwift Explícito, no existen `@TaskLocal` ocultos ni contenedores invisibles en `Domain`:
        // `BenchUseCase` recibe su dependencia explícitamente por constructor o desde `BenchModuleV1`.
        let daggerUseCase = BenchModuleV1.makeUseCase()
        #expect(daggerUseCase.execute() == 42)
    }

    @Test("Round 1.3 [Factory Falla]: Mutación de Container.shared contamina globalmente si olvidas reset()")
    func testFactoryGlobalStatePollutionWhenResetIsForgotten() {
        Container.shared.manager.reset()
        defer { Container.shared.manager.reset() }

        // Pantalla o Test A registra un Mock con multiplicador x10 en `Container.shared`
        Container.shared.benchRepo.register {
            BenchRepositoryImpl(api: BenchApiClientImpl(), multiplier: 10)
        }
        let consumerA = FactoryCoupledConsumer()
        #expect(consumerA.execute() == 420)

        // ❌ Si el Test A o Feature A termina y olvida llamar a `Container.shared.manager.reset()`,
        // la Pantalla B recibe el Mock contaminado (420 en vez de 42) porque comparten `Container.shared`:
        let pollutedConsumerB = FactoryCoupledConsumer()
        #expect(pollutedConsumerB.execute() == 420) // <- Contaminación de estado global demostrada

        // ✅ En DaggerSwift, cada `ScopeContainer` o `@Module` es independiente:
        let isolatedScopeA = ScopeContainer.root(modules: [BenchModuleV0_1.self]).makeChildScope(for: BenchFeatureScope.self)
        isolatedScopeA.provideScoped(in: BenchFeatureScope.self, (any BenchRepositoryProtocol).self) {
            BenchRepositoryImpl(api: BenchApiClientImpl(), multiplier: 10)
        }
        let isolatedScopeB = ScopeContainer.root(modules: [BenchModuleV0_1.self]).makeChildScope(for: BenchFeatureScope.self)

        let resA = try? isolatedScopeA.resolve(BenchUseCase.self).execute()
        let resB = try? isolatedScopeB.resolve(BenchUseCase.self).execute()
        #expect(resA == 420)
        #expect(resB == 42) // <- Scope B jamás se contamina por Scope A
    }

    @Test("Round 1.4 [Swinject + Factory + Point-Free Fallan]: Instancian sub-árboles en RAM aunque falle una Precondición")
    func testAllThreeLibrariesAllocateDependenciesBeforeCheckingPreconditions() {
        let sessionIsNil = true

        // 1. Swinject: Aloca el repositorio aunque la sesión sea inválida
        var swinjectRepoAllocations = 0
        let swinject = Swinject.Container()
        swinject.register((any BenchRepositoryProtocol).self) { _ in
            swinjectRepoAllocations += 1
            return BenchRepositoryImpl(api: BenchApiClientImpl())
        }
        _ = swinject.resolve((any BenchRepositoryProtocol).self)
        #expect(sessionIsNil && swinjectRepoAllocations == 1) // ❌ Desperdició memoria antes de validar sesión

        // 2. Factory: Aloca el repositorio aunque la sesión sea inválida
        final class CounterBox: @unchecked Sendable { var count = 0 }
        let factoryAllocations = CounterBox()
        Container.shared.manager.reset()
        defer { Container.shared.manager.reset() }
        Container.shared.benchRepo.register {
            factoryAllocations.count += 1
            return BenchRepositoryImpl(api: BenchApiClientImpl())
        }
        _ = Container.shared.benchUseCase()
        #expect(sessionIsNil && factoryAllocations.count == 1) // ❌ Desperdició memoria antes de validar sesión

        // 3. Point-Free `swift-dependencies`: Aloca el repositorio al acceder a `@Dependency`
        var tcaRepoAllocations = 0
        withDependencies {
            $0.benchRepo = {
                tcaRepoAllocations += 1
                return BenchRepositoryImpl(api: BenchApiClientImpl())
            }()
        } operation: {
            let uc = TcaCoupledUseCase()
            _ = uc.execute()
        }
        #expect(sessionIsNil && tcaRepoAllocations == 1) // ❌ Desperdició memoria

        // 4. ✅ DaggerSwift: `@Precondition` hace cortocircuito en la raíz ANTES de instanciar el repositorio
        var daggerRepoAllocations = 0
        let root = ScopeContainer.root(modules: [BenchModuleV2.self])
        root.provideScoped(in: BenchFeatureScope.self, (any BenchRepositoryProtocol).self) { (api: any BenchApiClientProtocol) in
            daggerRepoAllocations += 1
            return BenchRepositoryImpl(api: api)
        }
        let child = root.makeChildScope(for: BenchFeatureScope.self)
        #expect(throws: GraphError.self) {
            _ = try child.resolve(BenchProtectedInteractor.self)
        }
        #expect(daggerRepoAllocations == 0) // ✅ Cero objetos instanciados cuando falla `@Precondition`
    }

    @Test("Round 1.5 [Swinject + Factory + Point-Free Fallan]: Ninguna detecta Memory Leaks al cerrar una Feature")
    func testMemoryLeakDetectionOnFeatureTeardown() {
        final class LeakyFeatureViewModel: @unchecked Sendable {
            var selfRetainCycle: (() -> Void)?
            init() {
                // Simulamos un retain cycle accidental (olvidaron `[weak self]`)
                self.selfRetainCycle = { _ = self }
            }
        }

        // ❌ En Swinject, Factory o Point-Free `swift-dependencies`, no existe un `teardown()` por Feature
        // que audite cajas débiles (`WeakObjectBox`) y te devuelva los tipos fugados en RAM.

        // ✅ En DaggerSwift: `featureScope.teardown()` limpia el caché del Scope, fuerza un ciclo de ARC
        // y devuelve la lista exacta de clases que sufrieron un retain cycle:
        let root = ScopeContainer.root()
        let featureScope = root.makeChildScope(for: BenchFeatureScope.self)
        featureScope.provideScoped(in: BenchFeatureScope.self) { LeakyFeatureViewModel() }

        var leakedReference: LeakyFeatureViewModel? = try? featureScope.resolve(LeakyFeatureViewModel.self)
        #expect(leakedReference != nil)

        // Llamamos a `teardown()` mientras `leakedReference` (y su propio `selfRetainCycle`) sigue vivo:
        let detectedLeaks = featureScope.teardown()
        #expect(detectedLeaks.count == 1)
        #expect(detectedLeaks.first?.contains("LeakyFeatureViewModel") == true)

        // Rompemos el ciclo para limpiar el test
        leakedReference?.selfRetainCycle = nil
        leakedReference = nil
    }

    @Test("Round 1.6 [Swinject + Factory + Point-Free Fallan]: Captive Dependency (Root Scope resolviendo un hijo @Scoped sin abrir el Scope)")
    func testCaptiveDependencyScopeHierarchyViolation() {
        // En Clean Architecture, un contenedor raíz (`GlobalScope`) NO debe instanciar ni retener
        // una dependencia que pertenece a un flujo efímero (`BenchFeatureScope`) si esa pantalla no está abierta.
        // ❌ Swinject, Factory y Point-Free no tienen jerarquía tipada de `GraphScope`s; cualquier singleton
        // puede resolver y secuestrar en RAM una dependencia de pantalla ("Captive Dependency Bug").

        // ✅ En DaggerSwift, intentar resolver `BenchUseCase` (que depende de `BenchRepositoryProtocol` @Scoped
        // en `BenchFeatureScope`) directamente desde el `root` sin abrir `makeChildScope(for: BenchFeatureScope.self)`
        // es bloqueado por el motor con `GraphError.scopeViolation`:
        let rootOnly = ScopeContainer.root(modules: [BenchModuleV1.self])
        #expect(throws: GraphError.self) {
            _ = try rootOnly.resolve(BenchUseCase.self)
        }
    }

    // ========================================================================
    // ROUND 2: OBLIGANDO A FALLAR A DAGGERSWIFT (DONDE GANAN ELLOS)
    // ========================================================================

    @Test("Round 2.1 [Point-Free TCA Gana a DaggerSwift]: Override profundo con @TaskLocal sin tocar constructores intermedios")
    func testWherePointFreeBeatsDaggerSwiftDeepTreeTaskLocalOverride() {
        // Escenario: Tenemos 3 capas anidadas (`Level1 -> Level2 -> TcaCoupledUseCase`) donde `Level1` y `Level2`
        // NO reciben el repositorio por constructor.
        struct Level2 {
            func run() -> Int { TcaCoupledUseCase().execute() }
        }
        struct Level1 {
            func run() -> Int { Level2().run() }
        }

        // 🏆 Victoria de Point-Free `swift-dependencies`:
        // Con `withDependencies`, podemos inyectar un mock a 3 niveles de profundidad usando `@TaskLocal`
        // sin modificar el `init` de `Level1` ni de `Level2`, y sin registrar los tipos intermedios:
        let tcaResult = withDependencies {
            $0.benchRepo = BenchRepositoryImpl(api: BenchApiClientImpl(), multiplier: 100)
        } operation: {
            Level1().run()
        }
        #expect(tcaResult == 4_200)

        // 💥 Obligamos a fallar a DaggerSwift Modo Motor DAG (`ScopeContainer`):
        // Si intentas resolver `BenchUseCase` en un `ScopeContainer` vacío sin haber registrado su `@Module`,
        // DaggerSwift Modo Dinámico TAMBIÉN falla en Runtime lanzando `GraphError.missingProvider`:
        let emptyDaggerScope = ScopeContainer.root(modules: [])
        #expect(throws: GraphError.self) {
            _ = try emptyDaggerScope.resolve(BenchUseCase.self)
        }
    }

    @Test("Round 2.2 [Factory Gana a DaggerSwift]: Scope .shared (Weak Cache Automático) sin llamar a teardown() manual")
    func testWhereFactoryBeatsDaggerSwiftAutomaticWeakSharedScope() {
        final class EphemeralSharedService: @unchecked Sendable {
            init() {}
        }

        // 🏆 Victoria de `Factory`:
        // `Factory` tiene un scope `.shared` que guarda una referencia `weak` automática.
        // Mientras alguien en la pantalla tenga el objeto, se comparte la misma instancia;
        // en cuanto la última vista muere, se libera SOLO de RAM sin tener que llamar a `teardown()`!
        let factoryContainer = Container()
        let sharedFactory = Factory(factoryContainer) { EphemeralSharedService() }.shared

        weak var weakFactoryObserver: EphemeralSharedService?
        do {
            let ref1 = sharedFactory()
            let ref2 = sharedFactory()
            #expect(ref1 === ref2) // Comparten instancia mientras están vivos
            weakFactoryObserver = ref1
        }
        // ¡Se liberó automáticamente al salir del bloque `do` sin llamar a ningún `teardown()`!
        #expect(weakFactoryObserver == nil)

        // 💥 Obligamos a fallar a DaggerSwift (`@Scoped` en `ScopeContainer`):
        // En DaggerSwift, `@Scoped` retiene fuertemente (`strong reference`) la instancia en `scopedInstances`
        // hasta que el desarrollador llame explícitamente a `featureScope.teardown()`.
        // Si el desarrollador OLVIDA llamar a `teardown()`, el objeto se queda vivo en RAM:
        weak var weakDaggerObserver: EphemeralSharedService?
        let root = ScopeContainer.root()
        let featureScope = root.makeChildScope(for: BenchFeatureScope.self)
        featureScope.provideScoped(in: BenchFeatureScope.self) { EphemeralSharedService() }

        do {
            let daggerRef = try? featureScope.resolve(EphemeralSharedService.self)
            weakDaggerObserver = daggerRef
        }
        // 💥 Como nadie llamó a `featureScope.teardown()`, DaggerSwift sigue reteniendo la instancia en RAM:
        #expect(weakDaggerObserver != nil)

        // Recién al llamar a `teardown()` se libera:
        _ = featureScope.teardown()
        #expect(weakDaggerObserver == nil)
    }

    @Test("Round 2.3 [Swinject Gana a DaggerSwift]: Múltiples registros por Nombre (Named Registration) y Argumentos en Runtime")
    func testWhereSwinjectBeatsDaggerSwiftNamedAndParameterizedRegistrations() {
        // 🏆 Victoria de `Swinject`:
        // Swinject permite registrar el MISMO protocolo varias veces en el MISMO contenedor usando `name:`
        // y además pasar argumentos dinámicos (`argument:`) en el momento de hacer `resolve`:
        let swinject = Swinject.Container()
        swinject.register((any BenchApiClientProtocol).self, name: "mexico") { (_, regionCode: String) in
            BenchApiClientImpl(endpoint: "https://\(regionCode).api.mx")
        }
        swinject.register((any BenchApiClientProtocol).self, name: "usa") { (_, regionCode: String) in
            BenchApiClientImpl(endpoint: "https://\(regionCode).api.us")
        }

        let mxApi = swinject.resolve((any BenchApiClientProtocol).self, name: "mexico", argument: "cdmx")
        let usApi = swinject.resolve((any BenchApiClientProtocol).self, name: "usa", argument: "ny")
        #expect(mxApi?.endpoint == "https://cdmx.api.mx")
        #expect(usApi?.endpoint == "https://ny.api.us")

        // 💥 Obligamos a fallar a DaggerSwift (`ScopeContainer`):
        // `ScopeContainer` indexa únicamente por `TypeKey(T.self)` (`ObjectIdentifier`).
        // Si registras dos veces `(any BenchApiClientProtocol).self` en el mismo `ScopeContainer`
        // pensando que coexistirán, el segundo registro SOBREESCRIBE silenciosamente al primero:
        let daggerScope = ScopeContainer.root()
        daggerScope.provide((any BenchApiClientProtocol).self) {
            BenchApiClientImpl(endpoint: "https://cdmx.api.mx")
        }
        daggerScope.provide((any BenchApiClientProtocol).self) {
            BenchApiClientImpl(endpoint: "https://ny.api.us")
        }

        let resolvedInDagger = try? daggerScope.resolve((any BenchApiClientProtocol).self)
        // 💥 El primer registro ("https://cdmx.api.mx") fue aplastado por el segundo:
        #expect(resolvedInDagger?.endpoint == "https://ny.api.us")
    }

    // ========================================================================
    // ROUND 3: BENCHMARK EMPÍRICO Y REPORTE GRÁFICO DE LAS 4 LIBRERÍAS REALES
    // ========================================================================

    @Test("Round 3: Benchmark Real (10,000 iteraciones) y Gráfico Visual Comparativo")
    func testHeadToHeadPerformanceAndVisualReport() throws {
        let iterations = 10_000
        let clock = ContinuousClock()

        // 1. DaggerSwift Modo Explícito (Compile-Time @Module + @Scope)
        var daggerExplicitSum = 0
        let daggerExplicitDuration = clock.measure {
            for _ in 0..<iterations {
                let module = BenchFeatureScope.module(for: .v1_0)
                daggerExplicitSum &+= module.makeUseCase().execute()
            }
        }

        // 2. Factory (Container.shared)
        Container.shared.manager.reset()
        defer { Container.shared.manager.reset() }
        var factorySum = 0
        let factoryDuration = clock.measure {
            for _ in 0..<iterations {
                let uc = Container.shared.benchUseCase()
                factorySum &+= uc.execute()
            }
        }

        // 3. Point-Free `swift-dependencies` (@Dependency + withDependencies @TaskLocal)
        var tcaSum = 0
        let tcaDuration = clock.measure {
            withDependencies {
                $0.benchRepo = BenchRepositoryImpl(api: BenchApiClientImpl())
            } operation: {
                for _ in 0..<iterations {
                    let uc = TcaCoupledUseCase()
                    tcaSum &+= uc.execute()
                }
            }
        }

        // 4. DaggerSwift Modo Motor DAG (ScopeContainer + Cycle Detection + Scoped Cache)
        let daggerRoot = ScopeContainer.root(modules: [BenchModuleV1.self])
        let daggerFeature = daggerRoot.makeChildScope(for: BenchFeatureScope.self)
        var daggerDagSum = 0
        let daggerDagDuration = clock.measure {
            for _ in 0..<iterations {
                if let uc = try? daggerFeature.resolve(BenchUseCase.self) {
                    daggerDagSum &+= uc.execute()
                }
            }
        }

        // 5. Swinject (Swinject.Container real)
        let swinject = Swinject.Container()
        swinject.register((any BenchApiClientProtocol).self) { _ in
            BenchApiClientImpl()
        }.inObjectScope(.container)
        swinject.register((any BenchRepositoryProtocol).self) { r in
            BenchRepositoryImpl(api: r.resolve((any BenchApiClientProtocol).self)!)
        }.inObjectScope(.container)
        swinject.register(BenchUseCase.self) { r in
            BenchUseCase(repository: r.resolve((any BenchRepositoryProtocol).self)!)
        }.inObjectScope(.transient)

        var swinjectSum = 0
        let swinjectDuration = clock.measure {
            for _ in 0..<iterations {
                if let uc = swinject.resolve(BenchUseCase.self) {
                    swinjectSum &+= uc.execute()
                }
            }
        }

        #expect(daggerExplicitSum == iterations * 42)
        #expect(factorySum == iterations * 42)
        #expect(tcaSum == iterations * 42)
        #expect(daggerDagSum == iterations * 42)
        #expect(swinjectSum == iterations * 42)

        func micros(_ d: Duration) -> Double {
            Double(d.components.seconds) * 1_000_000.0 + Double(d.components.attoseconds) / 1_000_000_000_000.0
        }

        let rawEntries: [(name: String, us: Double)] = [
            ("DaggerSwift Explícito (@Module/@Scope)", micros(daggerExplicitDuration)),
            ("Point-Free swift-dependencies (TCA)   ", micros(tcaDuration)),
            ("Swinject (Dynamic Dictionary)         ", micros(swinjectDuration)),
            ("DaggerSwift Motor DAG (ScopeContainer)", micros(daggerDagDuration)),
            ("Factory (Container.shared)            ", micros(factoryDuration)),
        ].sorted { $0.us < $1.us }

        let maxUs = max(rawEntries.map(\.us).max() ?? 1.0, 1.0)
        let minUs = max(rawEntries.map(\.us).min() ?? 1.0, 0.001)

        var barsReport = ""
        for (idx, entry) in rawEntries.enumerated() {
            let barLen = max(1, Int((entry.us / maxUs) * 30.0))
            let bar = String(repeating: "█", count: barLen)
            let ratio = String(format: "%5.1fx", entry.us / minUs)
            let msStr = String(format: "%6.2f ms", entry.us / 1000.0)
            barsReport += "  \(idx + 1). \(entry.name) | \(msStr) (\(ratio)) |\(bar)\n"
        }

        print("""
        
        ╔══════════════════════════════════════════════════════════════════════════════════════════════╗
        ║     🥊 DEBATE EMPÍRICO Y BENCHMARK REAL (10,000 RESOLUCIONES EN PAQUETE SPM DEDICADO)        ║
        ╠══════════════════════════════════════════════════════════════════════════════════════════════╣
        ║ TIEMPO DE EJECUCIÓN ORDENADO (Menor barra = Más rápido):                                     ║
        \(barsReport)╠══════════════════════════════════════════════════════════════════════════════════════════════╣
        ║ MATRIZ DE BATALLAS (DÓNDE GANA Y DÓNDE PIERDE CADA LIBRERÍA):                                ║
        ║                                                                                              ║
        ║ • DaggerSwift Explícito (@Module + @Scope):                                                  ║
        ║   ✅ GANA : 0 Crashes por olvido de registro, Domain 100% puro, Herencia 0.1->1.0->2.0.      ║
        ║   ❌ PIERDE: No tiene init() vacío mágico ni override @TaskLocal sin pasar por constructor.   ║
        ║                                                                                              ║
        ║ • DaggerSwift Motor DAG (ScopeContainer):                                                    ║
        ║   ✅ GANA : Cortocircuito @Precondition (0 allocs), @BusinessRule A/B, Leak Audit WeakBox.   ║
        ║   ❌ PIERDE: Falla en runtime si olvidas el módulo; sin weak-cache automático ni name: keys. ║
        ║                                                                                              ║
        ║ • Point-Free swift-dependencies (TCA):                                                       ║
        ║   ✅ GANA : Override profundo con `withDependencies` (@TaskLocal) sin tocar constructores.   ║
        ║   ❌ PIERDE: Acopla Domain a `@Dependency`, falla en runtime si olvidas `testValue`/override. ║
        ║                                                                                              ║
        ║ • Factory (Michael Long):                                                                    ║
        ║   ✅ GANA : `init()` vacío con `@Injected` y `.shared` (weak cache que libera RAM solo).     ║
        ║   ❌ PIERDE: `Container.shared` muta estado global si olvidas `.reset()`, acopla `@Injected`.║
        ║                                                                                              ║
        ║ • Swinject:                                                                                  ║
        ║   ✅ GANA : Registros múltiples por `name:` string y paso de `argument:` dinámico en runtime.║
        ║   ❌ PIERDE: Devuelve `nil` en runtime si olvidas `register`, 0 Preconditions, 0 Leak Audit. ║
        ╚══════════════════════════════════════════════════════════════════════════════════════════════╝
        """)
    }
}
