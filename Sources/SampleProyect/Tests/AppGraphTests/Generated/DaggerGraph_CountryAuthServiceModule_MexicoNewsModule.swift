// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

/// Grafo generado para la raíz [CountryAuthServiceModule, MexicoNewsModule]: factories directas, sin `resolve`.
@MainActor
final class DaggerGraph_CountryAuthServiceModule_MexicoNewsModule {
    init() {}

    /// Abre el scope `CountryNewsScope` (sus `@Scoped` viven mientras viva el objeto devuelto).
    func makeCountryNewsScope() -> CountryNewsScopeGraph { CountryNewsScopeGraph(parent: self) }

    func authSessionRepository() -> AuthSessionRepository {
        AuthSessionRepository()
    }

    func authSessionRepositoryV2() -> AuthSessionRepositoryV2 {
        AuthSessionRepositoryV2()
    }

    func authenticatedCountrySession() throws -> AuthenticatedCountrySession {
        guard let value = MexicoNewsModule.validateSession(auth: countryAuthRepositoryProtocol()) else {
            throw GraphError.unmetPrecondition(type: String(reflecting: AuthenticatedCountrySession.self), reason: "Se requiere sesión activa en México (🇲🇽)")
        }
        return value
    }

    func countryAuthRepositoryImpl() -> CountryAuthRepositoryImpl {
        CountryAuthRepositoryImpl()
    }

    private var _countryAuthRepositoryProtocol: (any CountryAuthRepositoryProtocol)?
    func countryAuthRepositoryProtocol() -> any CountryAuthRepositoryProtocol {
        if let cached = _countryAuthRepositoryProtocol { return cached }
        let value = CountryAuthServiceModule.countryAuthRepository()
        _countryAuthRepositoryProtocol = value
        return value
    }

    func fakerGitHubRepository() -> FakerGitHubRepository {
        FakerGitHubRepository()
    }

    func featureFlagRepositoryImpl() -> FeatureFlagRepositoryImpl {
        FeatureFlagRepositoryImpl()
    }

    func fintechABFlagsRepositoryImpl() -> FintechABFlagsRepositoryImpl {
        FintechABFlagsRepositoryImpl()
    }

    func liveGitHubRepository() -> LiveGitHubRepository {
        LiveGitHubRepository()
    }
}
