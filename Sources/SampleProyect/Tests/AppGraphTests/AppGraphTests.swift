import Testing
import DaggerSwift
import DaggerSwiftTesting
import AppFoundation
import Core
import Services
import Features
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

// MARK: - Suite de Pruebas del Grafo de los 3 Demos

@Suite("2. Pruebas del Grafo de Dependencias (Demos 1, 2 y 3)")
struct AppGraphTests {

    // MARK: - Demo 1: Login Multi-Country + Home de Noticias Multi-Idioma (MX, US, BR, FR)

    @Test("Demo 1 (Multi-Country): Bloquea noticias sin login y resuelve en ES, EN, PT y FR tras autenticar", .tags(.precondition, .graph))
    func testDemo1MultiCountryLoginYNoticiasMultiIdioma() {
        // 1. México (Español): sin sesión falla por @Precondition, tras login resuelve noticias en es-MX
        expectGraph(CountryNewsCoreModule.self, CountryAuthServiceModule.self, MexicoNewsModule.self)
            .dependency(GetLocalizedNewsFeedUseCase.self).preconditionFailure()
            .when { (auth: any CountryAuthRepositoryProtocol) in
                auth.login(identifier: "+52 55 8421 0900", country: .mexico)
            }
            .dependency(GetLocalizedNewsFeedUseCase.self).resolved {
                $0.copy.languageCode == "es-MX" && !$0.headlines.isEmpty
            }

        // 2. USA (English): cumple el mismo contrato que México y resuelve en en-US
        expectWhenCondition(CountryNewsCoreModule.self, CountryAuthServiceModule.self, USANewsModule.self) { (auth: any CountryAuthRepositoryProtocol) in
            auth.login(identifier: "+1 415 890 4210", country: .usa)
        }
        .matchesContract(of: MexicoNewsModule.self)
        .dependency(GetLocalizedNewsFeedUseCase.self).resolved {
            $0.copy.languageCode == "en-US" && $0.copy.breakingTag == "BREAKING NEWS"
        }

        // 3. Brasil (Português) y Francia (Français): cumplen el mismo contrato y resuelven su idioma
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

    // MARK: - Demo 2: App Mockup Fintech (Evolución V1 -> V2 + @BusinessRule A/B Flags)

    @Test("Demo 2 (Fintech V1 -> V2 + A/B Flags): Evoluciona tarjeta a Metal V2 conservando Core Bancario V1 y conmuta A/B Flags", .tags(.businessRule, .graph))
    func testDemo2FintechEvolucionV1aV2YVariantesAB() {
        // 1. Con FintechModuleV1: Tarjeta Clásica V1 (isMetalV2 == false)
        expectGraph(FintechCoreModule.self, FintechSharedFlagsModule.self, FintechModuleV1.self)
            .dependency(GetFintechDashboardUseCase.self).hasNoPreconditions()
            .dependency(GetFintechDashboardUseCase.self).resolved {
                $0.cardEngine.fetchCardProduct().isMetalV2 == false &&
                $0.coreBanking.fetchAccountSummary().currency == "MXN"
            }

        // 2. Con FintechModuleV2 (@Module(includes: [FintechModuleV1.self])):
        //    Cumple el contrato de V1, hereda el Core Bancario de V1, actualiza a Metal V2 y conmuta los 2 A/B Flags en vivo
        expectGraph(FintechCoreModule.self, FintechSharedFlagsModule.self, FintechModuleV2.self)
            .matchesContract(of: FintechModuleV1.self)
            .dependency(GetFintechDashboardUseCase.self).resolved {
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

    // MARK: - Demo 3: GitHub Social Developer Profile (@fsaldivar-dev)

    @Test("Demo 3 (GitHub Feed): Inyectar Fake al vuelo y validar precondición del detalle de repositorio", .tags(.graph, .precondition))
    @MainActor
    func testDemo3GitHubFeedYPrecondicionDetalle() {
        expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self, RepoDetailModule.self)
            .matchesContract(of: LiveGitHubModule.self)
            .whenResolved(GitHubRepoItem.self).returns(.flagshipDaggerRepo)
            .dependency(GetProfileUseCase.self).hasNoPreconditions()
            .dependency(FeedViewModel.self).resolved()
            .dependency(RepoDetailInspector.self).preconditionFailure()
            .when { (auth: any AuthRepositoryProtocol) in
                auth.loginAsSaldivar()
            }
            .dependency(ValidatedSession.self).resolved()
            .dependency(RepoDetailInspector.self).resolved()
    }

    @Test("Módulo faltante: sin módulo de servicios falla con unresolvedFailure()", .tags(.graph))
    func testModuloFaltante() {
        expectGraph(ShowcaseCoreModule.self)
            .dependency((any GitHubRepositoryProtocol).self).unresolvedFailure()
            .dependency(GetProfileUseCase.self).unresolvedFailure()
            .dependency(GetRepositoriesUseCase.self).unresolvedFailure()
    }
}
