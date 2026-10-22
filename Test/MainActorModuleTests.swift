//
//  MainActorModuleTests.swift
//  @Module con @MainActor (objetos @Observable de SwiftUI, p. ej. Theme/UserPreferences en Ice Cubes).
//  Antes no compilaba: el closure de register(in:) no está aislado al MainActor.
//

import Testing
import DaggerSwift
import Observation

@MainActor
@Observable
final class MainActorModuleTheme {
    static let shared = MainActorModuleTheme()
    var tint = "blue"
}

protocol MainActorModuleToasts: AnyObject {}

@MainActor
final class MainActorModuleToastCenter: MainActorModuleToasts {}

@MainActor
@Module
enum MainActorAppModule {
    @Singleton
    static func theme() -> MainActorModuleTheme { .shared }

    /// Existencial no Sendable: también debe compilar.
    @Singleton
    static func toasts() -> any MainActorModuleToasts { MainActorModuleToastCenter() }

    /// `nonisolated` dentro de un módulo @MainActor: se construye sin saltar al MainActor.
    @Provider
    nonisolated static func greeting() -> String { "hola" }

    /// Parámetro existencial NO Sendable que entra al closure @MainActor: con concurrencia estricta
    /// fallaba con "sending … risks causing data races" (Firefox, AppSessionProvider).
    @Singleton
    static func toastCount(toasts: any MainActorModuleToasts) -> Int { toasts is MainActorModuleToastCenter ? 1 : 0 }
}

/// @Inject @MainActor con la misma dependencia no Sendable por init.
@MainActor
@Inject
final class MainActorModuleScreen {
    let toasts: any MainActorModuleToasts
}

@Suite("@Module @MainActor")
struct MainActorModuleTests {

    @MainActor
    @Test("Desde el MainActor se resuelve y el singleton es el mismo")
    func resolvesOnMainActor() async throws {
        let graph = ScopeContainer.root(modules: [MainActorAppModule.self])
        #if canImport(Darwin)
        let theme = try graph.resolve(MainActorModuleTheme.self)
        #else
        // En Linux el MainActor no corre necesariamente en el hilo principal y Swift no ofrece una
        // consulta pública de aislamiento sin trap: desde código @MainActor se usa resolveOnMainActor.
        let theme = try await graph.resolveOnMainActor(MainActorModuleTheme.self)
        #endif
        let sameTheme = theme === MainActorModuleTheme.shared
        #expect(sameTheme)
        #if canImport(Darwin)
        _ = try graph.resolve((any MainActorModuleToasts).self)
        #endif
        #expect(try graph.resolve(String.self) == "hola")
        #if canImport(Darwin)
        #expect(try graph.resolve(Int.self) == 1)
        _ = try graph.resolve(MainActorModuleScreen.self)
        #endif
    }

    @Test("Desde background: mainActorRequired (o resolveOnMainActor)")
    func backgroundThrowsTyped() async throws {
        let graph = ScopeContainer.root(modules: [MainActorAppModule.self])
        let error: GraphError? = await Task.detached {
            do { _ = try graph.resolve(MainActorModuleTheme.self); return nil }
            catch let e as GraphError { return e } catch { return nil }
        }.value
        #expect(error == .mainActorRequired(type: String(reflecting: MainActorModuleTheme.self)))
        // Una función nonisolated del módulo sí se resuelve desde background.
        let greeting = await Task.detached { try? graph.resolve(String.self) }.value
        #expect(greeting == "hola")
        let theme = try await Task.detached { try await graph.resolveOnMainActor(MainActorModuleTheme.self) }.value
        #expect(await theme.tint == "blue")
    }
}
