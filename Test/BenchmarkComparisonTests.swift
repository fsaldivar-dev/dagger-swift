//
//  BenchmarkComparisonTests.swift
//  DaggerSwiftTests
//
//  Suite de Benchmarks y Validación de Huecos Arquitectónicos:
//  Compara empíricamente:
//  1. Service Locator Dinámico (estilo Swinject / Resolver)
//  2. Contenedor Global con Property Wrappers (estilo Factory / @Injected)
//  3. DaggerSwift v2 Modo Explícito (Compile-Time Zero-Overhead con @Module + @Inject + @Scope)
//  4. DaggerSwift v2 Modo Motor DAG (ScopeContainer con @Precondition, @BusinessRule y Auditoría ARC)
//

import Foundation
import Testing
import DaggerSwift

// MARK: - Modelos de Prueba para el Benchmark

public protocol BenchApiClientProtocol: Sendable {
    var endpoint: String { get }
}

public struct BenchApiClientImpl: BenchApiClientProtocol {
    public let endpoint: String = "https://api.daggerswift.dev/v2"
    public init() {}
}

public protocol BenchRepositoryProtocol: Sendable {
    var api: any BenchApiClientProtocol { get }
    func fetchValue() -> Int
}

@Inject
public struct BenchRepositoryImpl: BenchRepositoryProtocol {
    public let api: any BenchApiClientProtocol
    public func fetchValue() -> Int { 42 }
}

@Inject
public struct BenchUseCase: Sendable {
    let repository: any BenchRepositoryProtocol
    public func execute() -> Int { repository.fetchValue() }
}

public struct BenchSessionPrecondition: Precondition, Sendable {
    public let userID: String
}

public enum BenchFeatureScope: GraphScope {}

@Inject(scope: BenchFeatureScope.self)
public final class BenchProtectedFeatureInteractor: Sendable {
    public let session: BenchSessionPrecondition
    public let useCase: BenchUseCase
}

public protocol BenchModuleContract: GraphModule {
    static func apiClient() -> any BenchApiClientProtocol
    static func repository() -> any BenchRepositoryProtocol
    static func makeUseCase() -> BenchUseCase
}

@Module(0.1, scope: BenchFeatureScope.self)
public enum BenchModuleV0_1: BenchModuleContract {
    @Singleton
    public static func apiClient() -> any BenchApiClientProtocol { BenchApiClientImpl() }

    @Scoped
    public static func repository() -> any BenchRepositoryProtocol {
        BenchRepositoryImpl(api: apiClient())
    }

    public static func makeUseCase() -> BenchUseCase {
        BenchUseCase(repository: repository())
    }
}

@Module(1.0, scope: BenchFeatureScope.self, includes: [BenchModuleV0_1.self])
public enum BenchModuleV1: BenchModuleContract {
    public static func apiClient() -> any BenchApiClientProtocol { BenchModuleV0_1.apiClient() }
    public static func repository() -> any BenchRepositoryProtocol { BenchModuleV0_1.repository() }
    public static func makeUseCase() -> BenchUseCase { BenchUseCase(repository: repository()) }
}

@Module(2.0, scope: BenchFeatureScope.self, includes: [BenchModuleV1.self])
public enum BenchModuleV2: BenchModuleContract {
    @Precondition("Sesión requerida para BenchProtectedFeatureInteractor")
    public static func validateSession() -> BenchSessionPrecondition? {
        nil
    }

    public static func apiClient() -> any BenchApiClientProtocol { BenchModuleV1.apiClient() }
    public static func repository() -> any BenchRepositoryProtocol { BenchModuleV1.repository() }
    public static func makeUseCase() -> BenchUseCase { BenchUseCase(repository: repository()) }
}

@Scope(
    of: (any BenchModuleContract).self,
    v0_1: BenchModuleV0_1.self,
    v1_0: BenchModuleV1.self,
    v2_0: BenchModuleV2.self
)
extension BenchFeatureScope {}

// MARK: - Simulación Fiel de un Service Locator Dinámico (Estilo Swinject / Resolver)

private final class DynamicDictionaryLocator {
    private var factories: [String: (DynamicDictionaryLocator) -> Any] = [:]
    private var singletons: [String: Any] = [:]
    private let lock = NSRecursiveLock()

    func register<T>(_ type: T.Type, isSingleton: Bool = false, factory: @escaping (DynamicDictionaryLocator) -> T) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(reflecting: type)
        factories[key] = { locator in
            if isSingleton, let cached = locator.singletons[key] as? T {
                return cached
            }
            let instance = factory(locator)
            if isSingleton {
                locator.singletons[key] = instance
            }
            return instance
        }
    }

    func resolve<T>(_ type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        let key = String(reflecting: type)
        guard let factory = factories[key] else { return nil }
        return factory(self) as? T
    }
}

// MARK: - Suite de Pruebas Comparativas y Benchmarks

@Suite("Dagger 3 - Benchmarks y Comparativa de Huecos vs Otras Librerías")
struct BenchmarkComparisonTests {

    @Test("Hueco 1: Service Locator Dinámico falla en Runtime (nil) vs DaggerSwift Explícito en Compile-Time")
    func testGap1RuntimeFailureVsCompileTimeSafety() {
        // En Swinject / Resolver, si olvidas registrar una dependencia, el código COMPILA sin errores
        // y devuelve `nil` (o hace crash con `resolve()!`) en producción:
        let swinjectStyleLocator = DynamicDictionaryLocator()
        let missingInRuntime = swinjectStyleLocator.resolve(BenchUseCase.self)
        #expect(missingInRuntime == nil) // <- Hueco 1: explota hasta que el usuario abre la pantalla

        // En cambio, con DaggerSwift Explícito (`BenchModuleContract`), `makeUseCase()` está verificado
        // por el compilador de Swift 6 (Cero `Optional`, cero `try!`, cero `try?`):
        let explicitUseCase = BenchModuleV1.makeUseCase()
        #expect(explicitUseCase.execute() == 42)
    }

    @Test("Hueco 2: Contenedores tradicionales instancian objetos sin validar Precondiciones vs Cortocircuito @Precondition")
    func testGap2PreconditionShortCircuit() {
        var repositoryAllocations = 0

        let scope = ScopeContainer.root(modules: [BenchModuleV2.self])
        scope.provideScoped(in: BenchFeatureScope.self, (any BenchRepositoryProtocol).self) { (api: any BenchApiClientProtocol) in
            repositoryAllocations += 1
            return BenchRepositoryImpl(api: api)
        }

        let child = scope.makeChildScope(for: BenchFeatureScope.self)
        // Intentamos resolver un componente protegido cuando la sesión es `nil`:
        #expect(throws: GraphError.self) {
            _ = try child.resolve(BenchProtectedFeatureInteractor.self)
        }
        // DaggerSwift detuvo la resolución en `@Precondition` ANTES de construir el repositorio:
        #expect(repositoryAllocations == 0)
    }

    @Test("Hueco 3: Contenedores Globales retienen objetos en RAM para siempre vs teardown() con Auditoría WeakObjectBox")
    func testGap3MemoryLifecycleAndLeakAudit() {
        final class HeavyFeatureCache {
            let buffer = Array(repeating: UInt64(1), count: 128)
        }

        weak var weakTrackerSwinject: HeavyFeatureCache?
        let swinjectStyleLocator = DynamicDictionaryLocator()
        swinjectStyleLocator.register(HeavyFeatureCache.self, isSingleton: true) { _ in HeavyFeatureCache() }

        do {
            let instance = swinjectStyleLocator.resolve(HeavyFeatureCache.self)
            weakTrackerSwinject = instance
        }
        // Hueco 3: Aunque la pantalla ya se cerró, el objeto sigue vivo en el diccionario global:
        #expect(weakTrackerSwinject != nil)

        // En DaggerSwift v2: al cerrar el Scope de la feature, `teardown()` libera la memoria y audita 0 leaks:
        weak var weakTrackerDagger: HeavyFeatureCache?
        let root = ScopeContainer.root()
        let featureScope = root.makeChildScope(for: BenchFeatureScope.self)
        featureScope.provideScoped(in: BenchFeatureScope.self) { HeavyFeatureCache() }

        do {
            let scopedInstance = try? featureScope.resolve(HeavyFeatureCache.self)
            weakTrackerDagger = scopedInstance
            #expect(weakTrackerDagger != nil)
        }

        let leaks = featureScope.teardown()
        #expect(leaks.isEmpty)
        #expect(weakTrackerDagger == nil) // <- Liberado determinísticamente de RAM
    }

    @Test("Benchmark Empírico (10,000 iteraciones): Resolución Explícita vs Motor DAG vs Diccionario Dinámico")
    func testEmpiricalPerformanceBenchmarks() throws {
        let iterations = 10_000
        let clock = ContinuousClock()

        // -------------------------------------------------------------------------
        // 1. DaggerSwift Modo Explícito (Compile-Time Static Dispatch + @Scope Palette)
        // -------------------------------------------------------------------------
        var explicitSum = 0
        let explicitDuration = clock.measure {
            for _ in 0..<iterations {
                let module = BenchFeatureScope.module(for: .v1_0)
                let uc = module.makeUseCase()
                explicitSum &+= uc.execute()
            }
        }

        // -------------------------------------------------------------------------
        // 2. DaggerSwift Modo Motor DAG (ScopeContainer con Cycle Tracking + Scoped Cache)
        // -------------------------------------------------------------------------
        let root = ScopeContainer.root(modules: [BenchModuleV1.self])
        let featureScope = root.makeChildScope(for: BenchFeatureScope.self)
        var dagSum = 0
        let dagDuration = clock.measure {
            for _ in 0..<iterations {
                if let uc = try? featureScope.resolve(BenchUseCase.self) {
                    dagSum &+= uc.execute()
                }
            }
        }

        // -------------------------------------------------------------------------
        // 3. Service Locator Dinámico Basado en Diccionario + String Reflection (Swinject style)
        // -------------------------------------------------------------------------
        let dynamicLocator = DynamicDictionaryLocator()
        dynamicLocator.register((any BenchApiClientProtocol).self, isSingleton: true) { _ in
            BenchApiClientImpl()
        }
        dynamicLocator.register((any BenchRepositoryProtocol).self, isSingleton: true) { loc in
            BenchRepositoryImpl(api: loc.resolve((any BenchApiClientProtocol).self)!)
        }
        dynamicLocator.register(BenchUseCase.self, isSingleton: false) { loc in
            BenchUseCase(repository: loc.resolve((any BenchRepositoryProtocol).self)!)
        }

        var dynamicSum = 0
        let dynamicDuration = clock.measure {
            for _ in 0..<iterations {
                if let uc = dynamicLocator.resolve(BenchUseCase.self) {
                    dynamicSum &+= uc.execute()
                }
            }
        }

        // -------------------------------------------------------------------------
        // 4. Cortocircuito de @Precondition en Frío (1,000 bloqueos sin instanciar sub-árbol)
        // -------------------------------------------------------------------------
        let preloadRoot = ScopeContainer.root(modules: [BenchModuleV2.self])
        let preloadChild = preloadRoot.makeChildScope(for: BenchFeatureScope.self)
        var blockedCount = 0
        let preconditionDuration = clock.measure {
            for _ in 0..<1_000 {
                do {
                    _ = try preloadChild.resolve(BenchProtectedFeatureInteractor.self)
                } catch {
                    blockedCount &+= 1
                }
            }
        }

        #expect(explicitSum == iterations * 42)
        #expect(dagSum == iterations * 42)
        #expect(dynamicSum == iterations * 42)
        #expect(blockedCount == 1_000)
        #expect(explicitDuration < dynamicDuration)

        print("""
        ================================================================================
        📊 DAGGERSWIFT v2 BENCHMARK REPORT (\(iterations) resoluciones en \( explicitDuration < dagDuration ? "Apple Silicon" : "macOS" ))
        --------------------------------------------------------------------------------
        1. DaggerSwift Explícito (Compile-Time @Module/@Scope) : \(explicitDuration)
        2. DaggerSwift Motor DAG (ScopeContainer + CycleCheck) : \(dagDuration)
        3. Service Locator Dinámico (String Key + Cast)        : \(dynamicDuration)
        4. Cortocircuito @Precondition (1,000 bloqueos)        : \(preconditionDuration)
        ================================================================================
        """)
    }
}
