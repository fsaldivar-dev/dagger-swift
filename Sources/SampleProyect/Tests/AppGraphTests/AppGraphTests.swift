import Testing
import DaggerSwift
import DaggerSwiftTesting
import AppFoundation
import Core
import Services
import Features
@testable import SampleProyect

// MARK: - 1. Fake exclusivo del Target de Tests (Cero Fakes en Release)

@Inject
final class FakerGitHubRepository: GitHubRepositoryProtocol, Sendable {
    let environmentTitle: String = "SANDBOX · Faker Offline"
    let isFakerEnvironment: Bool = true

    func fetchProfile(username: String) async throws -> GitHubUserProfile {
        .fsaldivarDefault
    }

    func fetchRepositories(username: String) async throws -> [GitHubRepoItem] {
        GitHubRepoItem.curatedRepositories
    }
}

/// Hereda `authRepository()` y `featureFlags()` de `LiveGitHubModule`
/// y solo reemplaza `gitHubRepository()` para pruebas offline.
@Module(includes: [LiveGitHubModule.self])
enum FakerGitHubModule {
    @Singleton
    static func gitHubRepository() -> any GitHubRepositoryProtocol {
        FakerGitHubRepository()
    }
}

// MARK: - 2. Ejemplo de Evolución (V1 -> V2) y Variantes Hermanas (Mex / Arg / Col)

/// Evolución `RepoDetailModule` (V1) -> `RepoDetailModuleV2` usando `includes:`:
/// `RepoDetailInspector` sigue teniendo `@Inject(scope: RepoDetailModule.self)` y funciona en V2 sin tocarlo.
@Module(includes: [RepoDetailModule.self])
enum RepoDetailModuleV2 {}

/// Scope compartido para variantes hermanas por país (México, Argentina, Colombia).
enum RegionalPaymentsScope: GraphScope {}

protocol PaymentGatewayProtocol: Sendable {
    var countryCode: String { get }
    var railName: String { get }
}

struct SPEIGateway: PaymentGatewayProtocol { let countryCode = "MX"; let railName = "SPEI" }
struct MercadoPagoGateway: PaymentGatewayProtocol { let countryCode = "AR"; let railName = "Transferencias 3.0" }
struct PSEGateway: PaymentGatewayProtocol { let countryCode = "CO"; let railName = "PSE" }

@Module(scope: RegionalPaymentsScope.self)
enum MexicoPaymentsModule {
    @Scoped
    static func gateway() -> any PaymentGatewayProtocol { SPEIGateway() }
}

@Module(scope: RegionalPaymentsScope.self)
enum ArgentinaPaymentsModule {
    @Scoped
    static func gateway() -> any PaymentGatewayProtocol { MercadoPagoGateway() }
}

@Module(scope: RegionalPaymentsScope.self)
enum ColombiaPaymentsModule {
    @Scoped
    static func gateway() -> any PaymentGatewayProtocol { PSEGateway() }
}

/// El hijo usa `@Inject(scope: RegionalPaymentsScope.self)` sin acoplarse a ningún país específico.
@Inject(scope: RegionalPaymentsScope.self)
struct RegionalCheckoutViewModel: Sendable {
    let gateway: any PaymentGatewayProtocol
}

// MARK: - 3. Suite de Pruebas del Grafo de Dependencias

@Suite("2. Pruebas del Grafo de Dependencias")
struct AppGraphTests {

    @Test("Inyectar Fakes al vuelo con whenResolved(...).returns(Fake.self)", .tags(.graph))
    @MainActor
    func testWhenResolvedReturnsFake() {
        expectGraph(ShowcaseCoreModule.self, LiveGitHubModule.self)
            .whenResolved((any GitHubRepositoryProtocol).self).returns(FakerGitHubRepository.self)
            .resolved(GetProfileUseCase.self)
            .resolved(GetRepositoriesUseCase.self)
            .resolved(FeedViewModel.self)
    }

    @Test("Evolución V1 -> V2: Hijos con @Inject(scope: V1) funcionan dentro de ModuleV2", .tags(.graph))
    func testEvolucionDeProductoV1aV2() {
        expectWhenCondition(ShowcaseCoreModule.self, LiveGitHubModuleV2.self, RepoDetailModuleV2.self) { (auth: any AuthRepositoryProtocol) in
            auth.loginAsSaldivar()
        }
        .matchesContract(of: LiveGitHubModule.self)
        .whenResolved(GitHubRepoItem.self).returns(.flagshipDaggerRepo)
        .dependency(ValidatedSession.self).resolved { $0.tokenFingerprint.hasPrefix("OAUTH-V2-") }
        // RepoDetailInspector tiene @Inject(scope: RepoDetailModule.self) (V1), pero resuelve dentro de RepoDetailModuleV2:
        .dependency(RepoDetailInspector.self).resolved()
    }

    @Test("Variantes Hermanas (Mex / Arg / Col): Hijos @Inject(scope:) resuelven según el país activo", .tags(.graph))
    func testVariantesHermanasPorPais() {
        expectGraph(MexicoPaymentsModule.self)
            .dependency(RegionalCheckoutViewModel.self).resolved { $0.gateway.countryCode == "MX" && $0.gateway.railName == "SPEI" }

        expectGraph(ArgentinaPaymentsModule.self)
            .matchesContract(of: MexicoPaymentsModule.self)
            .dependency(RegionalCheckoutViewModel.self).resolved { $0.gateway.countryCode == "AR" }

        expectGraph(ColombiaPaymentsModule.self)
            .matchesContract(of: MexicoPaymentsModule.self)
            .dependency(RegionalCheckoutViewModel.self).resolved { $0.gateway.countryCode == "CO" && $0.gateway.railName == "PSE" }
    }

    @Test("Composición completa con módulos: expectGraph(...).resolved(...)", .tags(.graph))
    @MainActor
    func testComposicionFlujoPrincipal() {
        expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self)
            .matchesContract(of: LiveGitHubModule.self)
            .resolved((any GitHubRepositoryProtocol).self)
            .resolved((any AuthRepositoryProtocol).self)
            .resolved((any FeatureFlagRepositoryProtocol).self)
            .resolved((any RepoExplorerStrategyProtocol).self)
            .resolved(GetProfileUseCase.self)
            .resolved(GetRepositoriesUseCase.self)
            .resolved(FeedViewModel.self)
    }

    @Test("Precondición: sin sesión falla con preconditionFailure() y tras login se resuelve", .tags(.precondition))
    func testPrecondicionSinNavegarScopes() {
        expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self, RepoDetailModule.self)
            .whenResolved(GitHubRepoItem.self).returns(.flagshipDaggerRepo)
            .dependency(GetProfileUseCase.self).hasNoPreconditions()
            .dependency(RepoDetailInspector.self).preconditionFailure()
            .when { (auth: any AuthRepositoryProtocol) in
                auth.loginAsSaldivar()
            }
            .dependency(ValidatedSession.self).resolved()
            .dependency(RepoDetailInspector.self).resolved()
    }

    @Test("Precondición directa con expectWhenCondition", .tags(.precondition))
    func testPrecondicionConExpectWhenCondition() {
        expectWhenCondition(ShowcaseCoreModule.self, FakerGitHubModule.self, RepoDetailModule.self) { (auth: any AuthRepositoryProtocol) in
            auth.loginAsSaldivar()
        }
        .whenResolved(GitHubRepoItem.self).returns(.flagshipDaggerRepo)
        .dependency(ValidatedSession.self).resolved()
        .dependency(RepoDetailInspector.self).resolved()
    }

    @Test("Regla de negocio (@BusinessRule): cambia de Bento v2 a Compacto v1", .tags(.businessRule))
    func testReglaDeNegocioConWhen() {
        expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self)
            .dependency((any RepoExplorerStrategyProtocol).self).resolved { $0.usesBentoGrid == true }
            .when { (flags: any FeatureFlagRepositoryProtocol) in
                flags.setBentoV2(false)
            }
            .dependency((any RepoExplorerStrategyProtocol).self).resolved { $0.usesBentoGrid == false }
    }

    @Test("Módulo faltante: sin módulo de servicios falla con unresolvedFailure()", .tags(.graph))
    func testModuloFaltante() {
        expectGraph(ShowcaseCoreModule.self)
            .dependency((any GitHubRepositoryProtocol).self).unresolvedFailure()
            .dependency(GetProfileUseCase.self).unresolvedFailure()
            .dependency(GetRepositoriesUseCase.self).unresolvedFailure()
    }
}
