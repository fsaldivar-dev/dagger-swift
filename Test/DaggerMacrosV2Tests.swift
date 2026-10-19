//
//  DaggerMacrosV2Tests.swift
//  DaggerSwift
//
//  Valida que las Swift Macros (@Module, @Inject, @Singleton, @Scoped, @Provider,
//  @BusinessRule, @Precondition) generen el grafo sin que el desarrollador toque ScopeContainer a mano.
//

import Foundation
import Testing
import DaggerSwift

// MARK: - Fixtures declarativas (lo único que escribe el desarrollador)

protocol MacroApiClient: Sendable { var id: String { get } }
final class MacroApiClientImpl: MacroApiClient { let id = UUID().uuidString }

final class MacroFlags: @unchecked Sendable { var useV2 = false }

protocol MacroCheckout { var version: String { get } }
struct MacroCheckoutA: MacroCheckout { let version = "A" }
struct MacroCheckoutB: MacroCheckout { let version = "B" }

final class MacroAuthStore: @unchecked Sendable { var token: String? }

struct MacroSession: Precondition { let token: String }

enum MacroLoansModule: GraphScope {}

@Module
enum MacroCoreModule {
    @Singleton
    static func apiClient() -> any MacroApiClient {
        MacroApiClientImpl()
    }

    @Singleton
    static func flags() -> MacroFlags {
        MacroFlags()
    }

    @Singleton
    static func auth() -> MacroAuthStore {
        MacroAuthStore()
    }

    @BusinessRule
    static func checkout(flags: MacroFlags) -> any MacroCheckout {
        flags.useV2 ? MacroCheckoutB() : MacroCheckoutA()
    }

    @Precondition("Se requiere sesión activa")
    static func session(auth: MacroAuthStore) -> MacroSession? {
        auth.token.map(MacroSession.init(token:))
    }
}

/// Cero `init` escrito a mano: lo genera @Inject.
@Inject(scope: MacroLoansModule.self)
final class MacroLoansRepository {
    let api: any MacroApiClient
    let session: MacroSession
}

@Inject
final class MacroLoansViewModel {
    let repo: MacroLoansRepository
    let checkout: any MacroCheckout
}

// MARK: - Tests

@Suite("DaggerSwift v2 - Swift Macros (@Module / @Inject)")
struct DaggerMacrosV2Tests {

    @Test("@Inject genera un init limpio usable en Unit Tests sin grafo")
    func injectGeneratesPlainInit() {
        let repo = MacroLoansRepository(api: MacroApiClientImpl(), session: MacroSession(token: "t"))
        #expect(repo.session.token == "t")
    }

    @Test("@Module registra @Singleton: misma instancia en todo el grafo")
    func moduleRegistersSingleton() throws {
        let graph = MacroCoreModule.buildGraph()
        let a = try graph.resolve((any MacroApiClient).self)
        let b = try graph.resolve((any MacroApiClient).self)
        #expect(a.id == b.id)
    }

    @Test("@BusinessRule cambia de variante A -> B en caliente")
    func businessRuleSwitches() throws {
        let graph = MacroCoreModule.buildGraph()
        #expect(try graph.resolve((any MacroCheckout).self).version == "A")
        try graph.resolve(MacroFlags.self).useV2 = true
        #expect(try graph.resolve((any MacroCheckout).self).version == "B")
    }

    @Test("@Precondition bloquea el sub-grafo antes de instanciar y se libera al iniciar sesión")
    func preconditionBlocksThenResolves() throws {
        let graph = MacroCoreModule.buildGraph()
        let loans = graph.makeChildScope(for: MacroLoansModule.self)

        #expect(throws: GraphError.self) {
            _ = try MacroLoansViewModel.resolve(in: loans)
        }
        #expect(loans.activeInstanceCount == 0)

        try graph.resolve(MacroAuthStore.self).token = "abc"
        let vm = try MacroLoansViewModel.resolve(in: loans)
        #expect(vm.repo.session.token == "abc")
    }

    @Test("@Inject(scope:) vive en su módulo y muere con teardown() sin fugas")
    func scopedInjectDiesWithModule() throws {
        let graph = MacroCoreModule.buildGraph()
        try graph.resolve(MacroAuthStore.self).token = "abc"
        let loans = graph.makeChildScope(for: MacroLoansModule.self)

        let vm1 = try MacroLoansViewModel.resolve(in: loans)
        let vm2 = try MacroLoansViewModel.resolve(in: loans)
        #expect(vm1 !== vm2)              // @Inject sin scope = transient
        #expect(vm1.repo === vm2.repo)    // @Inject(scope:) = compartido en el módulo

        // `weak var` + asignación (no `weak let`): `weak let` requiere Swift 6.2+ y el CI de Linux usa 6.1.
        weak var weakRepo: MacroLoansRepository?
        weakRepo = vm1.repo
        _ = consume vm1
        _ = consume vm2
        let leaks = loans.teardown()
        #expect(leaks.isEmpty)
        #expect(weakRepo == nil)
    }

    @Test("@Inject genera init(from container:) throws que propaga errores si falta una dependencia")
    func injectGeneratesThrowingContainerInit() throws {
        let graph = MacroCoreModule.buildGraph()
        let loans = graph.makeChildScope(for: MacroLoansModule.self)

        // Sin sesión, falla lanzando GraphError.unmetPrecondition
        #expect(throws: GraphError.self) {
            _ = try MacroLoansViewModel(from: loans)
        }

        // Con sesión, se inicializa exitosamente a través del throwing init
        try graph.resolve(MacroAuthStore.self).token = "abc"
        let vm = try MacroLoansViewModel(from: loans)
        #expect(vm.repo.session.token == "abc")
    }
}
