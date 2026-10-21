//
//  AppComposeTests.swift
//  @AppCompose / @Compose: RootComposer con resolución jerárquica (raíz → sesión → feature).
//

import Testing
import DaggerSwift

// MARK: - Fixture: un servicio global, una sesión con precondición y una feature bajo la sesión

final class ComposeApiClient {}
struct ComposeSession: Precondition, Sendable, Equatable { let user: String }
final class ComposeAuth { var user: String? }
final class ComposeRepository { let session: ComposeSession; init(session: ComposeSession) { self.session = session } }
final class ComposeUseCase { let repository: ComposeRepository; init(repository: ComposeRepository) { self.repository = repository } }
final class ComposeDraft { let repository: ComposeRepository; init(repository: ComposeRepository) { self.repository = repository } }
final class ComposeFlags { var bento = false }
protocol ComposeLayout { var name: String { get } }
struct ClassicLayout: ComposeLayout { let name = "classic" }
struct BentoLayout: ComposeLayout { let name = "bento" }

@Module
enum ComposeAppModule {
    @Singleton static func apiClient() -> ComposeApiClient { ComposeApiClient() }
    @Singleton static func auth() -> ComposeAuth { ComposeAuth() }
    @Singleton static func flags() -> ComposeFlags { ComposeFlags() }
    /// Se reevalúa en cada consulta: por eso en el compositor va como Provider<any ComposeLayout>.
    @BusinessRule static func layout(flags: ComposeFlags) -> any ComposeLayout {
        flags.bento ? BentoLayout() : ClassicLayout()
    }
}

@Module
enum ComposeSessionModule {
    @Precondition("Se requiere sesión iniciada")
    static func session(auth: ComposeAuth) -> ComposeSession? {
        auth.user.map(ComposeSession.init)
    }
    @Scoped static func repository(session: ComposeSession) -> ComposeRepository { ComposeRepository(session: session) }
    /// Una instancia por petición: en el compositor va como Provider<ComposeDraft>.
    @Provider static func draft(repository: ComposeRepository) -> ComposeDraft { ComposeDraft(repository: repository) }
}

@Module
enum ComposeFeatureModule {
    @Scoped static func useCase(repository: ComposeRepository) -> ComposeUseCase { ComposeUseCase(repository: repository) }
}

/// Lo que escribe la app: una lista por nivel. Nada más.
@AppCompose(ComposeAppModule.self)
final class ComposeHouse {
    let apiClient: ComposeApiClient
    let auth: ComposeAuth
    let flags: ComposeFlags
    let layout: Provider<any ComposeLayout>       // @BusinessRule: cada llamada reevalúa el flag
    let label = "no se pide al grafo"

    @Compose(ComposeSessionModule.self)
    struct Session {
        let session: ComposeSession          // @Precondition: init lanza si no hay usuario
        let repository: ComposeRepository
        let draft: Provider<ComposeDraft>    // @Provider: una instancia nueva por llamada

        @Compose(ComposeFeatureModule.self)
        struct Feature {
            let useCase: ComposeUseCase
        }
    }
}

@Suite("@AppCompose / @Compose")
struct AppComposeTests {

    @Test("La raíz resuelve sus lets una vez y expone el contenedor")
    func rootResolves() throws {
        let house = try ComposeHouse()
        #expect(house.apiClient === (try house.graph.resolve(ComposeApiClient.self)))
        #expect(house.label == "no se pide al grafo")
    }

    @Test("Sin sesión, openSession() lanza unmetPrecondition sin construir nada")
    func sessionBlocked() throws {
        let house = try ComposeHouse()
        #expect(throws: GraphError.self) { try house.openSession() }
        do {
            _ = try house.openSession()
        } catch let error as GraphError {
            guard case .unmetPrecondition(_, let reason) = error else { Issue.record("esperaba unmetPrecondition"); return }
            #expect(reason == "Se requiere sesión iniciada")
        }
    }

    @Test("Con sesión: raíz → sesión → feature, cada nivel bajo el contenedor del padre")
    func hierarchy() throws {
        let house = try ComposeHouse()
        house.auth.user = "saldivar"
        let session = try house.openSession()
        #expect(session.session.user == "saldivar")
        #expect(session.graph.parent === house.graph)

        let feature = try session.openFeature()
        #expect(feature.graph.parent === session.graph)
        #expect(feature.useCase.repository === session.repository)   // @Scoped compartido hacia abajo
    }

    @Test("close() cierra en cascada y el scope deja de servir")
    func closeCascades() throws {
        let house = try ComposeHouse()
        house.auth.user = "saldivar"
        let session = try house.openSession()
        let feature = try session.openFeature()
        _ = session.close()
        #expect(session.graph.isTornDown)
        #expect(feature.graph.isTornDown)
        // Reabrir: instancia nueva, independiente de la anterior
        let again = try house.openSession()
        #expect(again.repository !== session.repository)
    }

    @Test("Provider<T>: un @Provider da una instancia por llamada; un @BusinessRule se reevalúa")
    func providers() throws {
        let house = try ComposeHouse()
        house.auth.user = "saldivar"
        let session = try house.openSession()

        let a = try session.draft()
        let b = try session.draft()
        #expect(a !== b)
        #expect(a.repository === session.repository)           // la fábrica resuelve del scope de sesión

        #expect(try house.layout().name == "classic")
        house.flags.bento = true
        #expect(try house.layout().name == "bento")            // sin reabrir nada
    }
}
