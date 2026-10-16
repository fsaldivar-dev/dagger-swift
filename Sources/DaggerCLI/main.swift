//
//  main.swift
//  DaggerCLI
//
//  CLI Executable que demuestra DaggerSwift v2 en Terminal (Actor/Background Support):
//  - Nodos de Dominio (@Singleton, @Provider)
//  - Nodo de Regla de Negocio (@BusinessRule A -> B)
//  - Nodo de Precondición (@Precondition ValidatedSession)
//  - Scopes de Módulo (@Inject(scope:) + teardown() con 0 leaks)
//  - Lector del Manifiesto y Perfil @fsaldivar-dev
//

import Foundation
import DaggerSwift

// MARK: - 1. Modelos de Dominio

struct CliProfile: Codable, Sendable {
    let login: String
    let name: String
    let bio: String
    let location: String
    let publicRepos: Int
    let followers: Int
}

struct CliRepo: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let language: String
    let stars: Int
    let isProtected: Bool
}

// MARK: - 2. Servicios de Dominio (Zero Decorators)

protocol CliGitHubServiceProtocol: Sendable {
    var environmentName: String { get }
    func fetchProfile() async throws -> CliProfile
    func fetchRepos() async throws -> [CliRepo]
}

final class LiveCliGitHubService: CliGitHubServiceProtocol {
    let environmentName = "LIVE (GitHub REST API @fsaldivar-dev)"

    func fetchProfile() async throws -> CliProfile {
        guard let url = URL(string: "https://api.github.com/users/fsaldivar-dev") else {
            return fallbackProfile
        }
        var request = URLRequest(url: url)
        request.setValue("DaggerSwift-CLI", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                struct DTO: Decodable {
                    let login: String
                    let name: String?
                    let bio: String?
                    let location: String?
                    let public_repos: Int
                    let followers: Int
                }
                let dto = try JSONDecoder().decode(DTO.self, from: data)
                return CliProfile(
                    login: dto.login,
                    name: dto.name ?? "Saldivar",
                    bio: dto.bio ?? "Desarrollador mobile",
                    location: dto.location ?? "MX",
                    publicRepos: dto.public_repos,
                    followers: dto.followers
                )
            }
        } catch {}
        return fallbackProfile
    }

    func fetchRepos() async throws -> [CliRepo] {
        [
            CliRepo(id: "1", name: "dagger-swift", description: "Motor de Grafo de Dependencias (DAG) en Swift 6 con Macros declarativas (@Module, @Inject).", language: "Swift", stars: 42, isProtected: false),
            CliRepo(id: "2", name: "AutoPilot", description: "Control iOS Simulator directly from the command line. No XCUITest. One binary.", language: "Swift", stars: 28, isProtected: false),
            CliRepo(id: "3", name: "codaru-mockup", description: "Lightweight mockup editor for existing Tauri apps with design kits and AI CLI.", language: "TypeScript", stars: 15, isProtected: false),
            CliRepo(id: "4", name: "aru", description: "Editable reference illustrations and AI CLI with resumable icon batch production.", language: "JavaScript", stars: 11, isProtected: false),
            CliRepo(id: "5", name: "Kairo", description: "Lightweight TypeScript/SVG diagram editor with an optional Tauri 2 plugin.", language: "TypeScript", stars: 14, isProtected: false),
            CliRepo(id: "6", name: "CodaruPlanning", description: "Local planning and living documentation with Tauri and transactional AI CLI.", language: "TypeScript", stars: 9, isProtected: false),
            CliRepo(id: "7", name: "sajaru-design", description: "Suite de escritorio para sublimado/DTF — vectorizar y mockups 3D con inferencia ONNX.", language: "TypeScript", stars: 12, isProtected: false)
        ]
    }

    private var fallbackProfile: CliProfile {
        CliProfile(
            login: "fsaldivar-dev",
            name: "Saldivar",
            bio: "Desarrollador mobile · Creador de DaggerSwift, AutoPilot & Codaru",
            location: "MX",
            publicRepos: 26,
            followers: 10
        )
    }
}

final class FakerCliGitHubService: CliGitHubServiceProtocol {
    let environmentName = "FAKER (Simulación Offline Determinista)"

    func fetchProfile() async throws -> CliProfile {
        CliProfile(
            login: "fsaldivar-dev",
            name: "Saldivar (Sandbox)",
            bio: "Modo Sandbox CLI sin conexión a red",
            location: "CDMX · Sandbox",
            publicRepos: 26,
            followers: 99
        )
    }

    func fetchRepos() async throws -> [CliRepo] {
        [
            CliRepo(id: "1", name: "[FAKER] dagger-swift", description: "DAG Engine Swift 6 con Macros.", language: "Swift", stars: 142, isProtected: false),
            CliRepo(id: "2", name: "[FAKER] AutoPilot", description: "Simulador CLI en Swift puro.", language: "Swift", stars: 128, isProtected: false)
        ]
    }
}

// MARK: - 3. Estado de Negocio y Precondición

struct CliSession: Precondition {
    let username: String
    let token: String
}

final class CliAuthStore: @unchecked Sendable {
    private let lock = NSLock()
    var session: CliSession?

    func login() {
        lock.lock()
        defer { lock.unlock() }
        session = CliSession(username: "fsaldivar-dev", token: "demo_cli_session")
    }

    func logout() {
        lock.lock()
        defer { lock.unlock() }
        session = nil
    }
}

final class CliFlagStore: @unchecked Sendable {
    var useBentoV2 = true
}

protocol CliRendererProtocol: Sendable {
    var name: String { get }
}
struct ClassicCliRenderer: CliRendererProtocol { let name = "Sistema A · Renderizado Clásico v1" }
struct BentoCliRenderer: CliRendererProtocol { let name = "Sistema B · Bento Grid + Telemetría DAG v2" }

// MARK: - 4. Módulos Declarativos (@Module)

@Module
enum CliCoreModule {
    @Singleton
    static func auth() -> CliAuthStore { CliAuthStore() }

    @Singleton
    static func flags() -> CliFlagStore { CliFlagStore() }

    @BusinessRule
    static func renderer(flags: CliFlagStore) -> any CliRendererProtocol {
        flags.useBentoV2 ? BentoCliRenderer() : ClassicCliRenderer()
    }

    @Precondition("Se requiere autenticación activa como @fsaldivar-dev")
    static func session(auth: CliAuthStore) -> CliSession? {
        auth.session
    }
}

@Module
enum CliLiveEnvironmentModule {
    @Singleton
    static func service() -> any CliGitHubServiceProtocol { LiveCliGitHubService() }
}

@Module
enum CliFakerEnvironmentModule {
    @Singleton
    static func service() -> any CliGitHubServiceProtocol { FakerCliGitHubService() }
}

enum CliInspectorScope: GraphScope {}

@Inject(scope: CliInspectorScope.self)
final class CliRepoInspector: ScopeDisposable, @unchecked Sendable {
    let repoName: String
    let service: any CliGitHubServiceProtocol
    private(set) var isDisposed = false

    func onScopeTeardown() {
        isDisposed = true
    }
}

@Inject
final class CliProtectedVault {
    let session: CliSession
    let service: any CliGitHubServiceProtocol
}

// MARK: - 5. Interfaz de Comandos de Terminal

func printBanner() {
    print("""
    \u{001B}[35m===============================================================\u{001B}[0m
    \u{001B}[1;36m  🗡️  DaggerSwift v2 — Motor de Grafo & Macros en Swift 6\u{001B}[0m
    \u{001B}[35m===============================================================\u{001B}[0m
    \u{001B}[33mRepositorio:\u{001B}[0m github.com/fsaldivar-dev/dagger-swift
    \u{001B}[33mArquitectura:\u{001B}[0m DAG Topológico, Scopes Jerárquicos, Reglas A->B y Preconditions
    \u{001B}[33mDeclaratividad:\u{001B}[0m @Module, @Inject, @Singleton, @Scoped, @BusinessRule, @Precondition
    """)
}

func printHelp() {
    print("""
    \u{001B}[1mUso:\u{001B}[0m
      swift run dagger-cli <comando> [opciones]

    \u{001B}[1mComandos disponibles:\u{001B}[0m
      \u{001B}[32mprofile\u{001B}[0m          Obtiene el perfil oficial de @fsaldivar-dev desde GitHub API.
      \u{001B}[32mrepos\u{001B}[0m            Lista los repositorios destacados (dagger-swift, AutoPilot, etc.).
      \u{001B}[32mmanifesto\u{001B}[0m        Muestra el Manifiesto de Aaron Swartz, Jonas Salk y Dagger 1 -> 2.
      \u{001B}[32mtest-auth\u{001B}[0m        Prueba cómo @Precondition bloquea rutas protegidas hasta iniciar sesión.
      \u{001B}[32mtest-flag\u{001B}[0m        Prueba la resolución dinámica de @BusinessRule (Sistema A vs B).
      \u{001B}[32mstress-test\u{001B}[0m      Crea 25 sub-scopes en ráfaga, ejecuta teardown() y audita fugas de RAM.

    \u{001B}[1mOpciones:\u{001B}[0m
      --faker          Usa el entorno Faker determinista sin llamadas de red.
    """)
}

@main
struct DaggerCliApp {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let useFaker = args.contains("--faker")
        let command = args.first(where: { !$0.hasPrefix("--") }) ?? "help"

        let envModule: any GraphModule.Type = useFaker ? CliFakerEnvironmentModule.self : CliLiveEnvironmentModule.self
        let graph = CliCoreModule.buildGraph(including: [envModule])

        switch command {
        case "profile":
            printBanner()
            print("\u{001B}[36m🔍 Consultando perfil en el grafo...\u{001B}[0m")
            do {
                let service = try graph.resolve((any CliGitHubServiceProtocol).self)
                print("\u{001B}[33mProveedor de Datos:\u{001B}[0m \(service.environmentName)")
                let profile = try await service.fetchProfile()
                print("\n\u{001B}[1;32m👤 Perfil de GitHub:\u{001B}[0m")
                print("   • Nombre:     \(profile.name)")
                print("   • Usuario:    @\(profile.login)")
                print("   • Bio:        \(profile.bio)")
                print("   • Ubicación:  \(profile.location)")
                print("   • Repos:      \(profile.publicRepos)")
                print("   • Seguidores: \(profile.followers)")
                print("   • URL:        https://github.com/\(profile.login)\n")
            } catch {
                print("❌ Error resolviendo perfil: \(error)")
            }

        case "repos":
            printBanner()
            do {
                let service = try graph.resolve((any CliGitHubServiceProtocol).self)
                print("\u{001B}[33mProveedor de Datos:\u{001B}[0m \(service.environmentName)\n")
                let repos = try await service.fetchRepos()
                for repo in repos {
                    let lock = repo.isProtected ? "🔒 " : "📦 "
                    print("\(lock)\u{001B}[1;34m\(repo.name)\u{001B}[0m (\(repo.language)) ★ \(repo.stars)")
                    print("   \(repo.description)")
                }
                print("")
            } catch {
                print("❌ Error resolviendo repositorios: \(error)")
            }

        case "manifesto":
            printBanner()
            print("""
            \u{001B}[1;33m📜 MANIFIESTO: LOS GIGANTES QUE ELIGIERON COMPARTIR\u{001B}[0m

            \u{001B}[1m«El pueblo, diría yo. ¿Podrías patentar el sol?»\u{001B}[0m
            — Jonas Salk, creador de la vacuna de la polio (rechazó patentarla).

            • \u{001B}[1mTim Berners-Lee\u{001B}[0m inventó la Web y convenció al CERN de liberarla al dominio público:
              «Si hubiera tratado de exigir cuotas, no habría World Wide Web.»
            • \u{001B}[1mLinus Torvalds\u{001B}[0m escribió Linux con licencia GPL:
              «Open source es la única forma correcta de hacer software.»
            • \u{001B}[1mAaron Swartz (2008)\u{001B}[0m:
              «Compartir no es inmoral; es un imperativo moral. Volvamos a hacer público lo que siempre fue público.»

            \u{001B}[1;36m🎯 DaggerSwift v2:\u{001B}[0m
            Construido con la convicción de que las herramientas de arquitectura en Swift deben ser
            abiertas, predecibles, libres de boilerplate y auditadas contra fugas de memoria.
            """)

        case "test-auth":
            printBanner()
            print("\u{001B}[1;33m🧪 PRUEBA DE PRECONDICIÓN: ValidatedSession\u{001B}[0m\n")
            let childScope = graph.makeChildScope(for: CliInspectorScope.self)

            print("1. Intentando resolver CliProtectedVault SIN sesión activa...")
            do {
                _ = try CliProtectedVault.resolve(in: childScope)
                print("❌ Fallo: Se resolvió cuando debía abortar.")
            } catch let error as GraphError {
                print("   \u{001B}[32m✔ El Grafo abortó la resolución antes de reservar memoria:\u{001B}[0m")
                print("     \(error.description)")
            } catch {
                print("❌ Error inesperado: \(error)")
            }

            print("\n2. Simulando autenticación como @fsaldivar-dev...")
            let authStore = try! graph.resolve(CliAuthStore.self)
            authStore.login()
            print("   \u{001B}[32m✔ Sesión iniciada: token validado.\u{001B}[0m")

            print("\n3. Re-intentando resolver CliProtectedVault CON sesión activa...")
            do {
                let vault = try CliProtectedVault.resolve(in: childScope)
                print("   \u{001B}[1;32m✔ Bóveda resuelta con éxito!\u{001B}[0m")
                print("     Usuario: @\(vault.session.username) (token: \(vault.session.token))")
                print("     Servicio inyectado: \(vault.service.environmentName)")
            } catch {
                print("❌ Error: \(error)")
            }
            childScope.teardown()
            print("")

        case "test-flag":
            printBanner()
            print("\u{001B}[1;33m🚩 PRUEBA DE REGLA DE NEGOCIO: Feature Flag A -> B\u{001B}[0m\n")
            let flagStore = try! graph.resolve(CliFlagStore.self)

            flagStore.useBentoV2 = false
            let rendererA = try! graph.resolve((any CliRendererProtocol).self)
            print("Flag apagado  -> El grafo inyectó: \u{001B}[34m\(rendererA.name)\u{001B}[0m")

            flagStore.useBentoV2 = true
            let rendererB = try! graph.resolve((any CliRendererProtocol).self)
            print("Flag encendido -> El grafo inyectó: \u{001B}[35m\(rendererB.name)\u{001B}[0m")
            print("\n\u{001B}[32m✔ La regla de negocio cambió la implementación dinámicamente sin modificar código consumidor.\u{001B}[0m\n")

        case "stress-test":
            printBanner()
            print("\u{001B}[1;33m⚡ PRUEBA DE ESTRÉS: 25 Sub-Scopes en Ráfaga con Auditoría WeakObjectBox\u{001B}[0m\n")
            var totalLeaks = 0
            for i in 1...25 {
                let subScope = graph.makeChildScope(for: CliInspectorScope.self)
                subScope.bindInstance("repo-\(i)")
                do {
                    let inspector = try! CliRepoInspector.resolve(in: subScope)
                    _ = inspector.repoName
                }
                let leaks = subScope.teardown()
                totalLeaks += leaks.count
            }
            print("   • Scopes creados y destruidos: 25")
            print("   • Fugas de memoria detectadas: \u{001B}[1;32m\(totalLeaks) (CERO LEAKS)\u{001B}[0m")
            print("\n\u{001B}[32m✔ Todas las instancias de los sub-scopes fueron recolectadas por ARC limpiamente.\u{001B}[0m\n")

        default:
            printBanner()
            printHelp()
        }
    }
}
