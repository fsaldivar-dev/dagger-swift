//
//  DaggerShowcaseGraph.swift
//  SampleProyect
//
//  Grafo DAG del Showcase escrito 100% declarativo con DaggerSwift v2 (Dagger 2 style):
//  - @Module      → módulos que son su propio Scope y declaran nodos con funciones estáticas.
//  - @Singleton   → nodos de dominio globales (lazy).
//  - @BusinessRule→ Feature Flag A -> B (Sistema Clásico vs. Bento).
//  - @Precondition→ ValidatedSession: bloquea el sub-grafo antes de instanciar nada.
//  - @Inject      → genera el init limpio (Unit Tests sin grafo) + autoregistro Just-In-Time.
//
//  Nadie en la app llama a `provideSingleton` ni a `provideScoped` a mano.
//

import Foundation
import DaggerSwift

// MARK: - 1. Nodo de Precondición (Cold-Start Auth Guard)

public struct ValidatedSession: Precondition {
    public let userID: String
    public let username: String
    public let tokenPreview: String
    public let role: String
    public let authenticatedAt: Date

    public init(
        userID: String = "16517868",
        username: String = "fsaldivar-dev",
        tokenPreview: String = "ghp_daggerV2_99x81a",
        role: String = "Owner & Architect",
        authenticatedAt: Date = Date()
    ) {
        self.userID = userID
        self.username = username
        self.tokenPreview = tokenPreview
        self.role = role
        self.authenticatedAt = authenticatedAt
    }
}

public final class AuthSessionStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var currentSession: ValidatedSession?

    public init(initialSession: ValidatedSession? = nil) {
        self.currentSession = initialSession
    }

    public var isAuthenticated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentSession != nil
    }

    public var session: ValidatedSession? {
        lock.lock()
        defer { lock.unlock() }
        return currentSession
    }

    @discardableResult
    public func loginAsSaldivar() -> ValidatedSession {
        lock.lock()
        defer { lock.unlock() }
        let s = ValidatedSession()
        currentSession = s
        return s
    }

    public func logout() {
        lock.lock()
        defer { lock.unlock() }
        currentSession = nil
    }
}

// MARK: - 2. Nodo de Regla de Negocio (Feature Flag: Sistema A vs Sistema B)

public enum ExplorerLayoutVariant: String, Sendable, Equatable {
    case classicV1 = "Sistema A · Lista Clásica (v1)"
    case bentoV2   = "Sistema B · Bento + Telemetría DAG (v2)"
}

public protocol RepoExplorerStrategyProtocol: Sendable {
    var variant: ExplorerLayoutVariant { get }
    var badgeTitle: String { get }
    var accentDescription: String { get }
    var showsArchitectureTelemetry: Bool { get }
    var usesBentoGrid: Bool { get }
}

public final class ClassicRepoExplorerStrategy: RepoExplorerStrategyProtocol {
    public let variant: ExplorerLayoutVariant = .classicV1
    public let badgeTitle: String = "RAMA A · CLÁSICO"
    public let accentDescription: String = "Renderizado compacto tradicional inyectado cuando el Feature Flag está apagado."
    public let showsArchitectureTelemetry: Bool = false
    public let usesBentoGrid: Bool = false
    public let service: any GitHubServiceProtocol

    public init(service: any GitHubServiceProtocol) {
        self.service = service
    }
}

public final class BentoRepoExplorerStrategy: RepoExplorerStrategyProtocol {
    public let variant: ExplorerLayoutVariant = .bentoV2
    public let badgeTitle: String = "RAMA B · BENTO DAG V2"
    public let accentDescription: String = "Tarjetas enriquecidas con métricas de arquitectura, licencias y árbol de archivos inyectadas por Regla de Negocio."
    public let showsArchitectureTelemetry: Bool = true
    public let usesBentoGrid: Bool = true
    public let service: any GitHubServiceProtocol
    public let manifestoRepo: ManifestoRepository

    public init(service: any GitHubServiceProtocol, manifestoRepo: ManifestoRepository) {
        self.service = service
        self.manifestoRepo = manifestoRepo
    }
}

public final class FeatureFlagStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var bentoV2: Bool

    public init(isBentoV2Enabled: Bool = true) {
        self.bentoV2 = isBentoV2Enabled
    }

    public var isBentoV2Enabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return bentoV2
    }

    public func setBentoV2(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        bentoV2 = enabled
    }
}

// MARK: - 3. Módulos del Grafo (@Module = su propio Scope, sin CodingKeys manuales)

/// Núcleo del Showcase. Declara los nodos globales, la regla de negocio y la precondición.
/// Pide `any GitHubServiceProtocol` pero NO lo produce: lo aporta el módulo de entorno
/// (`LiveGitHubModule` en Demo, `FakerGitHubModule` en DemoFaker / CLI --faker).
@Module
public enum ShowcaseCoreModule {

    @Singleton
    static func manifestoRepository() -> ManifestoRepository {
        ManifestoRepository()
    }

    @Singleton
    static func authSession() -> AuthSessionStateBox {
        AuthSessionStateBox()
    }

    @Singleton
    static func featureFlags() -> FeatureFlagStateBox {
        FeatureFlagStateBox()
    }

    @BusinessRule
    static func explorerStrategy(
        flags: FeatureFlagStateBox,
        service: any GitHubServiceProtocol,
        manifesto: ManifestoRepository
    ) -> any RepoExplorerStrategyProtocol {
        if flags.isBentoV2Enabled {
            return BentoRepoExplorerStrategy(service: service, manifestoRepo: manifesto)
        }
        return ClassicRepoExplorerStrategy(service: service)
    }

    @Precondition("Se requiere sesión activa de @fsaldivar-dev para abrir módulos protegidos")
    static func validatedSession(auth: AuthSessionStateBox) -> ValidatedSession? {
        auth.session
    }
}

/// Entorno de producción (target Demo): GitHub REST API real.
@Module
public enum LiveGitHubModule {
    @Singleton
    static func gitHubService() -> any GitHubServiceProtocol {
        LiveGitHubService()
    }
}

/// Entorno offline determinista (target DemoFaker / CLI --faker).
@Module
public enum FakerGitHubModule {
    @Singleton
    static func gitHubService() -> any GitHubServiceProtocol {
        FakerGitHubService()
    }
}

/// Scope del detalle de un repositorio: vive mientras la pantalla de detalle está abierta.
@Module
public enum RepoDetailModule {}

/// Scope de la bóveda privada: vive mientras la bóveda está abierta.
@Module
public enum PrivateVaultModule {}

// MARK: - 4. Clases de Feature con @Inject (cero init escrito a mano)

/// Vive en `RepoDetailModule`. Recibe el repo vía `bindInstance` (equivalente a `@BindsInstance`).
@Inject(scope: RepoDetailModule.self)
public final class RepoDetailInspector: ScopeDisposable, @unchecked Sendable {
    public let repo: GitHubRepoItem
    public let service: any GitHubServiceProtocol

    public let instanceID = "Inspector-" + String(UUID().uuidString.prefix(4))
    public let createdAt = Date()
    public private(set) var isDisposed = false

    public var serviceEnvironment: String { service.environmentTitle }

    public func onScopeTeardown() {
        isDisposed = true
    }
}

/// Acceso a un repo protegido. `session` va PRIMERO: si la precondición falla,
/// el grafo aborta antes de construir el `RepoDetailInspector`.
@Inject
public final class ProtectedRepoAccess {
    public let session: ValidatedSession
    public let inspector: RepoDetailInspector
}

/// Vive en `PrivateVaultModule` y exige `ValidatedSession` por constructor.
@Inject(scope: PrivateVaultModule.self)
public final class PrivateVaultInteractor: ScopeDisposable, @unchecked Sendable {
    public let session: ValidatedSession
    public let service: any GitHubServiceProtocol

    public let instanceID = "Vault-" + String(UUID().uuidString.prefix(4))
    public private(set) var isDisposed = false

    public var secretKeys: [String] {
        [
            "DAGGER_SIGNING_KEY_V2 = sha256:9f86d081884c7d659a2feaa0c55ad015",
            "GITHUB_APP_INSTALLATION = @" + session.username + " #" + session.userID,
            "ZERO_TRUST_PRECONDITION = ValidatedSession VERIFIED",
            "ENVIRONMENT_PROVIDER = " + service.environmentTitle
        ]
    }

    public func onScopeTeardown() {
        isDisposed = true
    }
}

// MARK: - 5. Bitácora de eventos

public struct ScopeEventLog: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let category: String
    public let message: String
    public let isError: Bool

    public init(category: String, message: String, isError: Bool = false) {
        self.timestamp = Date()
        self.category = category
        self.message = message
        self.isError = isError
    }
}

// MARK: - 6. Composition Root

/// Punto único donde se arma el grafo. Solo elige qué módulo de entorno usar;
/// todo lo demás lo declaran los `@Module` y `@Inject`.
public final class DaggerShowcaseAssembler: @unchecked Sendable {
    public let rootContainer: ScopeContainer
    public let authBox: AuthSessionStateBox
    public let featureFlagBox: FeatureFlagStateBox

    public init(
        environment: any GraphModule.Type,
        initiallyAuthenticated: Bool = false,
        initialBentoV2Flag: Bool = true
    ) {
        let root = ShowcaseCoreModule.buildGraph(including: [environment])
        self.rootContainer = root
        // Los singletons son lazy: se crean aquí por primera vez, al pedirlos.
        self.authBox = try! root.resolve(AuthSessionStateBox.self)
        self.featureFlagBox = try! root.resolve(FeatureFlagStateBox.self)

        if initiallyAuthenticated { authBox.loginAsSaldivar() }
        featureFlagBox.setBentoV2(initialBentoV2Flag)
    }

    /// Abre el scope `RepoDetailModule`. Si el repo es protegido, exige `ValidatedSession`.
    public func openRepositoryScope(
        for repo: GitHubRepoItem,
        requiresAuth: Bool = false
    ) throws -> (scope: ScopeContainer, inspector: RepoDetailInspector) {
        let childScope = rootContainer.makeChildScope(for: RepoDetailModule.self)
        childScope.bindInstance(repo)

        do {
            let inspector: RepoDetailInspector
            if requiresAuth || repo.isPrivateVault {
                inspector = try ProtectedRepoAccess.resolve(in: childScope).inspector
            } else {
                inspector = try RepoDetailInspector.resolve(in: childScope)
            }
            return (childScope, inspector)
        } catch {
            childScope.teardown()
            throw error
        }
    }

    /// Abre el scope `PrivateVaultModule`, protegido por `ValidatedSession`.
    public func openPrivateVaultScope() throws -> (scope: ScopeContainer, vault: PrivateVaultInteractor) {
        let vaultScope = rootContainer.makeChildScope(for: PrivateVaultModule.self)
        do {
            let vault = try PrivateVaultInteractor.resolve(in: vaultScope)
            return (vaultScope, vault)
        } catch {
            vaultScope.teardown()
            throw error
        }
    }
}
