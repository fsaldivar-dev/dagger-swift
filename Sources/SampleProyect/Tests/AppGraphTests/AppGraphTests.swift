import Testing
import DaggerSwift
import DaggerSwiftTesting
import AppFoundation
import Core
import Services
import Features
import MultiCountryNewsDemo
import FintechMockupDemo
@testable import SampleProyect

// MARK: - Fake exclusivo del Target de Tests (Cero Fakes en Release)

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

@Module(includes: [LiveGitHubModule.self])
enum FakerGitHubModule {
    @Singleton
    static func gitHubRepository() -> any GitHubRepositoryProtocol {
        FakerGitHubRepository()
    }
}

// MARK: - Suite de Pruebas del Grafo de Dependencias

@Suite("2. Pruebas del Grafo de Dependencias (Demos 1, 2 y 3)")
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

    // MARK: - Demo 1: Target `MultiCountryNewsDemo` (MX, US, BR, FR)

    @Test("Demo 1 (MultiCountryNewsDemo): Bloquea noticias sin login y resuelve en ES, EN, PT y FR tras autenticar", .tags(.precondition, .graph))
    func testDemo1MultiCountryLoginYNoticiasMultiIdioma() {
        expectGraph(CountryNewsCoreModule.self, CountryAuthServiceModule.self, MexicoNewsModule.self)
            .dependency(GetLocalizedNewsFeedUseCase.self).preconditionFailure()
            .when { (auth: any CountryAuthRepositoryProtocol) in
                auth.login(identifier: "+52 55 8421 0900", country: .mexico)
            }
            .dependency(GetLocalizedNewsFeedUseCase.self).resolved {
                $0.copy.languageCode == "es-MX" && !$0.headlines.isEmpty
            }

        expectWhenCondition(CountryNewsCoreModule.self, CountryAuthServiceModule.self, USANewsModule.self) { (auth: any CountryAuthRepositoryProtocol) in
            auth.login(identifier: "+1 415 890 4210", country: .usa)
        }
        .matchesContract(of: MexicoNewsModule.self)
        .dependency(GetLocalizedNewsFeedUseCase.self).resolved {
            $0.copy.languageCode == "en-US" && $0.copy.breakingTag == "BREAKING NEWS"
        }

        expectWhenCondition(CountryNewsCoreModule.self, CountryAuthServiceModule.self, BrazilNewsModule.self) { (auth: any CountryAuthRepositoryProtocol) in
            auth.login(identifier: "CPF 391.820.118-09", country: .brazil)
        }
        .matchesContract(of: MexicoNewsModule.self)
        .dependency(GetLocalizedNewsFeedUseCase.self).resolved { $0.copy.languageCode == "pt-BR" }

        expectWhenCondition(CountryNewsCoreModule.self, CountryAuthServiceModule.self, FranceNewsModule.self) { (auth: any CountryAuthRepositoryProtocol) in
            auth.login(identifier: "+33 6 42 88 19 00", country: .france)
        }
        .matchesContract(of: MexicoNewsModule.self)
        .dependency(GetLocalizedNewsFeedUseCase.self).resolved { $0.copy.languageCode == "fr-FR" }
    }

    // MARK: - Demo 2: Target `FintechMockupDemo` con Paleta `@Module(0.1)`, `@Module(1.0)`, `@Module(2.0)` + A/B Flags

    @Test("Demo 2 (FintechMockupDemo): Paleta @Module(0.1) -> @Module(1.0) -> @Module(2.0) y A/B Flags", .tags(.businessRule, .graph))
    func testDemo2FintechPaleta01_10_20YVariantesAB() {
        #expect(FintechModuleV0_1.moduleVersion == "0.1")
        #expect(FintechModuleV1.moduleVersion == "1.0")
        #expect(FintechModuleV2.moduleVersion == "2.0")

        // 1. Module(0.1): Starter MVP 0.1
        expectGraph(FintechCoreModule.self, FintechSharedFlagsModule.self, FintechModuleV0_1.self)
            .dependency(GetFintechDashboardUseCase.self).hasNoPreconditions()
            .dependency(GetFintechDashboardUseCase.self).resolved {
                $0.cardEngine.fetchCardProduct().moduleVersionTag.contains("Module(0.1)")
            }

        // 2. Module(1.0): hereda Core Bancario de 0.1 y sube a Classic Card 1.0
        expectGraph(FintechCoreModule.self, FintechSharedFlagsModule.self, FintechModuleV1.self)
            .matchesContract(of: FintechModuleV0_1.self)
            .dependency(GetFintechDashboardUseCase.self).resolved {
                $0.cardEngine.fetchCardProduct().moduleVersionTag.contains("Module(1.0)") &&
                $0.cardEngine.fetchCardProduct().isMetalV2 == false
            }

        // 3. Module(2.0): hereda Core Bancario y sube a Metal V2 + conmuta A/B Flags en vivo
        expectGraph(FintechCoreModule.self, FintechSharedFlagsModule.self, FintechModuleV2.self)
            .matchesContract(of: FintechModuleV1.self)
            .dependency(GetFintechDashboardUseCase.self).resolved {
                $0.cardEngine.fetchCardProduct().moduleVersionTag.contains("Module(2.0)") &&
                $0.cardEngine.fetchCardProduct().isMetalV2 == true &&
                $0.layoutVariant.variantCode == "B" &&
                $0.creditOfferVariant.experimentCode == "Exp-B"
            }
            .when { (flags: any FintechABFlagsRepositoryProtocol) in
                flags.setWealthBentoVariantB(false)
                flags.setInstantCreditBoostVariantB(false)
            }
            .dependency(GetFintechDashboardUseCase.self).resolved {
                $0.layoutVariant.variantCode == "A" &&
                $0.creditOfferVariant.experimentCode == "Control-A"
            }
    }
}
