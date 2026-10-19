// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

/// Grafo generado para la raíz [CountryAuthServiceModule, FranceNewsModule]: factories directas, sin `resolve`.
@MainActor
final class DaggerGraph_CountryAuthServiceModule_FranceNewsModule {
    init() {}

    /// Abre el scope `CountryNewsScope` (sus `@Scoped` viven mientras viva el objeto devuelto).
    func makeCountryNewsScope() -> CountryNewsScopeGraph { CountryNewsScopeGraph(parent: self) }

    func authSessionRepository() throws -> AuthSessionRepository {
        AuthSessionRepository()
    }

    func authSessionRepositoryV2() throws -> AuthSessionRepositoryV2 {
        AuthSessionRepositoryV2()
    }

    func authenticatedCountrySession() throws -> AuthenticatedCountrySession {
        guard let value = try FranceNewsModule.validateSession(auth: countryAuthRepositoryProtocol()) else {
            throw GraphError.unmetPrecondition(type: String(reflecting: AuthenticatedCountrySession.self), reason: "Session active en France (🇫🇷) requise")
        }
        return value
    }

    func countryAuthRepositoryImpl() throws -> CountryAuthRepositoryImpl {
        CountryAuthRepositoryImpl()
    }

    private var _countryAuthRepositoryProtocol: (any CountryAuthRepositoryProtocol)?
    func countryAuthRepositoryProtocol() throws -> any CountryAuthRepositoryProtocol {
        if let cached = _countryAuthRepositoryProtocol { return cached }
        let value = CountryAuthServiceModule.countryAuthRepository()
        _countryAuthRepositoryProtocol = value
        return value
    }

    func fakerGitHubRepository() throws -> FakerGitHubRepository {
        FakerGitHubRepository()
    }

    func featureFlagRepositoryImpl() throws -> FeatureFlagRepositoryImpl {
        FeatureFlagRepositoryImpl()
    }

    func fintechABFlagsRepositoryImpl() throws -> FintechABFlagsRepositoryImpl {
        FintechABFlagsRepositoryImpl()
    }

    func liveGitHubRepository() throws -> LiveGitHubRepository {
        LiveGitHubRepository()
    }
}
