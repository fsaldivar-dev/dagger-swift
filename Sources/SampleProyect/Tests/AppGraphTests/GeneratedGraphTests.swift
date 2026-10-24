//
//  GeneratedGraphTests.swift
//  AppGraphTests
//
//  El grafo generado por `dagger-graph generate` (Generated/) debe comportarse igual que el runtime:
//  @Singleton = misma instancia, @Scoped = una por scope, @Precondition bloquea hasta cumplirse.
//  Regenerar: ver Tools/DaggerGraph/SPIKE.md.
//

import Testing
import DaggerSwift
import AppFoundation
import Core
import Services
import Features

@Suite("Grafo generado (dagger-graph generate)")
@MainActor
struct GeneratedGraphTests {

    @Test("Singletons, scope y precondición con factories directas (sin resolve)")
    func generatedGraphMatchesRuntimeSemantics() throws {
        let graph = DaggerGraph_ShowcaseCoreModule_FakerGitHubModule_RepoDetailModule()

        // @Singleton: misma instancia; el Fake del test sobrescribe a LiveGitHubModule (includes).
        let repoA = graph.gitHubRepositoryProtocol() as AnyObject
        let repoB = graph.gitHubRepositoryProtocol() as AnyObject
        // (Bool precalculado: `#expect(a === b)` hace crashear al compilador 6.3 al reabstraer `===`.)
        let sameSingleton = repoA === repoB
        #expect(sameSingleton)
        #expect(graph.gitHubRepositoryProtocol().isFakerEnvironment)

        // @Precondition: sin sesión, el scope de detalle no se construye.
        let detail = graph.makeRepoDetailModule()
        #expect(throws: GraphError.self) { _ = try detail.repoDetailInspector() }

        graph.authRepositoryProtocol().loginAsSaldivar()
        let inspectorA = try detail.repoDetailInspector()
        let inspectorB = try detail.repoDetailInspector()
        let sameScope = inspectorA === inspectorB
        #expect(sameScope)
        #expect(inspectorA.session.username == "fsaldivar-dev")

        // Otro scope = otra instancia.
        let otherScopeInspector = try graph.makeRepoDetailModule().repoDetailInspector()
        let distinct = otherScopeInspector !== inspectorA
        #expect(distinct)

        // Transient @Inject con dependencias directas.
        let vm = graph.feedViewModel()
        let auth = graph.authRepositoryProtocol() as AnyObject
        let sharedAuth = (vm.authRepository as AnyObject) === auth
        #expect(sharedAuth)
    }
}
