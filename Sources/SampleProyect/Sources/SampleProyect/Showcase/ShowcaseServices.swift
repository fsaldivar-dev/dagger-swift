//
//  ShowcaseServices.swift
//  SampleProyect
//
//  Servicios de Dominio y Datos (@fsaldivar-dev GitHub API Live, Faker Offline y Manifiesto).
//  Diseñados bajo el principio de DaggerSwift v2: Cero decoradores invasivos en las clases.
//

import Foundation

public protocol GitHubServiceProtocol: Sendable {
    var environmentTitle: String { get }
    var isFakerEnvironment: Bool { get }
    func fetchProfile(username: String) async throws -> GitHubUserProfile
    func fetchRepositories(username: String) async throws -> [GitHubRepoItem]
}

// MARK: - Live GitHub API Implementation (Demo target)

public final class LiveGitHubService: GitHubServiceProtocol {
    public let environmentTitle: String = "LIVE · GitHub REST API (@fsaldivar-dev)"
    public let isFakerEnvironment: Bool = false

    public init() {}

    private struct GitHubAPIUserDTO: Decodable {
        let login: String
        let name: String?
        let bio: String?
        let location: String?
        let avatar_url: String
        let html_url: String
        let public_repos: Int
        let followers: Int
        let following: Int
    }

    private struct GitHubAPIRepoDTO: Decodable {
        struct LicenseDTO: Decodable {
            let spdx_id: String?
            let name: String?
        }
        let id: Int
        let name: String
        let full_name: String
        let description: String?
        let language: String?
        let stargazers_count: Int
        let forks_count: Int
        let open_issues_count: Int
        let html_url: String
        let default_branch: String?
        let size: Int?
        let license: LicenseDTO?
    }

    public func fetchProfile(username: String) async throws -> GitHubUserProfile {
        guard let url = URL(string: "https://api.github.com/users/\(username)") else {
            return .fsaldivarDefault
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("DaggerSwift-v2-Showcase", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .fsaldivarDefault
            }
            let dto = try JSONDecoder().decode(GitHubAPIUserDTO.self, from: data)
            return GitHubUserProfile(
                login: dto.login,
                name: dto.name ?? "Saldivar",
                bio: dto.bio ?? "Desarrollador mobile",
                location: dto.location ?? "MX",
                avatarURL: dto.avatar_url,
                htmlURL: dto.html_url,
                publicRepos: dto.public_repos,
                followers: dto.followers,
                following: dto.following
            )
        } catch {
            return .fsaldivarDefault
        }
    }

    public func fetchRepositories(username: String) async throws -> [GitHubRepoItem] {
        guard let url = URL(string: "https://api.github.com/users/\(username)/repos?sort=updated&per_page=20") else {
            return Self.curatedRepositories
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("DaggerSwift-v2-Showcase", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return Self.curatedRepositories
            }
            let dtos = try JSONDecoder().decode([GitHubAPIRepoDTO].self, from: data)
            var mapped: [GitHubRepoItem] = dtos.map { dto in
                let enrichment = Self.enrichment(for: dto.name)
                return GitHubRepoItem(
                    id: dto.id,
                    name: dto.name,
                    fullName: dto.full_name,
                    description: dto.description ?? enrichment.fallbackDescription,
                    language: dto.language ?? enrichment.fallbackLanguage,
                    stars: max(dto.stargazers_count, enrichment.starsFloor),
                    forks: dto.forks_count,
                    openIssues: dto.open_issues_count,
                    htmlURL: dto.html_url,
                    defaultBranch: dto.default_branch ?? "main",
                    isPrivateVault: dto.name.lowercased().contains("vault"),
                    sizeKB: dto.size ?? 1024,
                    licenseName: dto.license?.spdx_id ?? "MIT",
                    architectureNotes: enrichment.architectureNotes,
                    sampleFiles: enrichment.sampleFiles
                )
            }

            if !mapped.contains(where: { $0.name.lowercased() == "dagger-swift" }) {
                mapped.insert(Self.flagshipDaggerRepo, at: 0)
            } else if let idx = mapped.firstIndex(where: { $0.name.lowercased() == "dagger-swift" }) {
                let item = mapped.remove(at: idx)
                mapped.insert(item, at: 0)
            }

            mapped.insert(Self.privateVaultRepo, at: 1)
            return mapped
        } catch {
            return Self.curatedRepositories
        }
    }

    public static let flagshipDaggerRepo = GitHubRepoItem(
        id: 87654321,
        name: "dagger-swift",
        fullName: "fsaldivar-dev/dagger-swift",
        description: "Motor de Grafo de Dependencias (DAG) y Scopes Jerárquicos en Swift 6. Nodos de Dominio, Reglas de Negocio (Feature Flags A->B) y Precondiciones (Cold-Start Auth).",
        language: "Swift",
        stars: 42,
        forks: 5,
        openIssues: 0,
        htmlURL: "https://github.com/fsaldivar-dev/dagger-swift",
        defaultBranch: "main",
        isPrivateVault: false,
        sizeKB: 3420,
        licenseName: "GPL-3.0",
        architectureNotes: """
        • v1.0.0: Experimento original con @Singleton, @Provider y protocolo Modulable estático.
        • v2.0.0: Motor DAG jerárquico con ScopeContainer, Parameter Packs (repeat each D), detección de ciclos, Precondition para Deep Links y liberación automática de memoria con WeakObjectBox.
        """,
        sampleFiles: [
            "Sources/DaggerSwift/GraphScope.swift",
            "Sources/DaggerSwift/ScopeContainer.swift",
            "Sources/DaggerSwift/SwiftUIGraph.swift",
            "Sources/DaggerSwift/Module.swift",
            "MEMORIA_DAGGER_V1.md",
            "MANIFESTO.md"
        ]
    )

    public static let privateVaultRepo = GitHubRepoItem(
        id: 99999901,
        name: "dagger-enterprise-vault",
        fullName: "fsaldivar-dev/dagger-enterprise-vault",
        description: "🔒 Bóveda protegida por Precondition (ValidatedSession). Requiere sesión activa antes de que el grafo instancie el módulo.",
        language: "Swift",
        stars: 19,
        forks: 2,
        openIssues: 0,
        htmlURL: "https://github.com/fsaldivar-dev/dagger-swift",
        defaultBranch: "main",
        isPrivateVault: true,
        sizeKB: 1280,
        licenseName: "Enterprise-Protected",
        architectureNotes: """
        Este nodo del grafo exige `ValidatedSession.self` como parámetro en su `init`.
        Si un Deep Link intenta abrirlo sin sesión activa, `ScopeContainer` aborta la construcción con `GraphError.unmetPrecondition` antes de reservar memoria.
        """,
        sampleFiles: [
            "Vault/ZeroTrustGraphModule.swift",
            "Vault/SessionPreconditionGuard.swift",
            "Vault/EncryptedKeysStore.swift"
        ]
    )

    public static let curatedRepositories: [GitHubRepoItem] = [
        flagshipDaggerRepo,
        privateVaultRepo,
        GitHubRepoItem(
            id: 1198459556,
            name: "AutoPilot",
            fullName: "fsaldivar-dev/AutoPilot",
            description: "Control iOS Simulator directly from the command line. No XCUITest. No server. No dependencies. One binary.",
            language: "Swift",
            stars: 28,
            forks: 3,
            openIssues: 12,
            htmlURL: "https://github.com/fsaldivar-dev/AutoPilot",
            defaultBranch: "main",
            isPrivateVault: false,
            sizeKB: 20236,
            licenseName: "MIT",
            architectureNotes: "CLI nativo en Swift de un solo binario para automatizar el Simulador de iOS y Android desde terminal sin servidores intermedios.",
            sampleFiles: ["Sources/AutoPilotCLI/main.swift", "Sources/SimulatorBridge/HIDController.swift", "Package.swift"]
        ),
        GitHubRepoItem(
            id: 1402177076,
            name: "codaru-mockup",
            fullName: "fsaldivar-dev/codaru-mockup",
            description: "Lightweight mockup editor for existing Tauri apps, with design kits, themes, icons and an AI CLI",
            language: "TypeScript",
            stars: 15,
            forks: 1,
            openIssues: 0,
            htmlURL: "https://github.com/fsaldivar-dev/codaru-mockup",
            defaultBranch: "main",
            isPrivateVault: false,
            sizeKB: 11356,
            licenseName: "BSD-3-Clause",
            architectureNotes: "Editor ligero de mockups para aplicaciones Tauri con kits de diseño, temas e interfaz CLI para agentes IA.",
            sampleFiles: ["src/editor/CanvasStage.tsx", "src-tauri/src/main.rs", "cli/codaru-ai.ts"]
        ),
        GitHubRepoItem(
            id: 1409454676,
            name: "aru",
            fullName: "fsaldivar-dev/aru",
            description: "Editable reference illustrations, embeddable studio and AI CLI with resumable icon batch production",
            language: "JavaScript",
            stars: 11,
            forks: 1,
            openIssues: 0,
            htmlURL: "https://github.com/fsaldivar-dev/aru",
            defaultBranch: "main",
            isPrivateVault: false,
            sizeKB: 1999,
            licenseName: "MIT",
            architectureNotes: "Estudio embebible de ilustraciones editables y producción por lotes de iconos mediante CLI.",
            sampleFiles: ["studio/VectorEngine.js", "cli/batch-icons.js", "README.md"]
        ),
        GitHubRepoItem(
            id: 1401908393,
            name: "Kairo",
            fullName: "fsaldivar-dev/Kairo",
            description: "Lightweight TypeScript/SVG diagram editor with an optional Tauri 2 plugin",
            language: "TypeScript",
            stars: 14,
            forks: 2,
            openIssues: 0,
            htmlURL: "https://github.com/fsaldivar-dev/Kairo",
            defaultBranch: "main",
            isPrivateVault: false,
            sizeKB: 790,
            licenseName: "BSD-3-Clause",
            architectureNotes: "Motor ligero de diagramación SVG/TypeScript con plugin para Tauri 2.",
            sampleFiles: ["src/graph/DAGLayout.ts", "src/svg/EdgeRenderer.ts"]
        ),
        GitHubRepoItem(
            id: 1402182422,
            name: "CodaruPlanning",
            fullName: "fsaldivar-dev/CodaruPlanning",
            description: "Local planning and living documentation with Tauri, Kairo and a transactional AI CLI",
            language: "TypeScript",
            stars: 9,
            forks: 0,
            openIssues: 0,
            htmlURL: "https://github.com/fsaldivar-dev/CodaruPlanning",
            defaultBranch: "main",
            isPrivateVault: false,
            sizeKB: 670,
            licenseName: "BSD-3-Clause",
            architectureNotes: "Planeación local y documentación viva integrada con Kairo y CLI transaccional.",
            sampleFiles: ["src/planning/BoardView.tsx", "cli/tx-planner.ts"]
        ),
        GitHubRepoItem(
            id: 1287515808,
            name: "sajaru-design",
            fullName: "fsaldivar-dev/sajaru-design",
            description: "Suite de escritorio para agencias de sublimado y DTF — quitar fondo, vectorizar, mockups 3D con video 360°.",
            language: "TypeScript",
            stars: 12,
            forks: 1,
            openIssues: 0,
            htmlURL: "https://github.com/fsaldivar-dev/sajaru-design",
            defaultBranch: "main",
            isPrivateVault: false,
            sizeKB: 8450,
            licenseName: "MIT",
            architectureNotes: "Suite con inferencia ONNX local para remover fondos, vectorización y render 3D 360°.",
            sampleFiles: ["src/onnx/BackgroundRemover.ts", "src/three/Mockup360.tsx"]
        )
    ]

    private static func enrichment(for repoName: String) -> (fallbackDescription: String, fallbackLanguage: String, starsFloor: Int, architectureNotes: String, sampleFiles: [String]) {
        if let found = curatedRepositories.first(where: { $0.name.lowercased() == repoName.lowercased() }) {
            return (found.description, found.language, found.stars, found.architectureNotes, found.sampleFiles)
        }
        return (
            "Repositorio Open Source de @fsaldivar-dev explorado mediante el grafo de DaggerSwift v2.",
            "Swift",
            4,
            "Módulo inspeccionado dinámicamente creando un sub-scope hijo (`RepoDetailModule`) con liberación determinista al cerrar la vista.",
            ["README.md", "Package.swift", "Sources/Main.swift"]
        )
    }
}

// MARK: - Faker Offline Implementation (DemoFaker / "iphone due" target)

public final class FakerGitHubService: GitHubServiceProtocol {
    public let environmentTitle: String = "FAKER · Simulación Offline Determinista (DemoFaker)"
    public let isFakerEnvironment: Bool = true

    public init() {}

    public func fetchProfile(username: String) async throws -> GitHubUserProfile {
        GitHubUserProfile(
            login: "fsaldivar-dev",
            name: "Saldivar (Faker Sandbox)",
            bio: "Modo Sandbox determinista inyectado por DemoFaker sin llamadas de red · Swift 6 DAG",
            location: "CDMX · Sandbox",
            avatarURL: "https://avatars.githubusercontent.com/u/16517868?v=4",
            htmlURL: "https://github.com/fsaldivar-dev",
            publicRepos: 26,
            followers: 99,
            following: 12
        )
    }

    public func fetchRepositories(username: String) async throws -> [GitHubRepoItem] {
        LiveGitHubService.curatedRepositories.map { repo in
            GitHubRepoItem(
                id: repo.id,
                name: repo.name,
                fullName: repo.fullName,
                description: "[FAKER] " + repo.description,
                language: repo.language,
                stars: repo.stars + 100,
                forks: repo.forks + 10,
                openIssues: repo.openIssues,
                htmlURL: repo.htmlURL,
                defaultBranch: repo.defaultBranch,
                isPrivateVault: repo.isPrivateVault,
                sizeKB: repo.sizeKB,
                licenseName: repo.licenseName,
                architectureNotes: "[Nodo inyectado desde AppModuleFaker] " + repo.architectureNotes,
                sampleFiles: repo.sampleFiles
            )
        }
    }
}

// MARK: - Manifesto & Technical Memory Repository

public final class ManifestoRepository: Sendable {
    public init() {}

    public func fetchChapters() -> [ManifestoChapter] {
        [
            ManifestoChapter(
                id: "gigantes",
                badge: "CAPÍTULO I · MANIFIESTO",
                title: "Los gigantes que eligieron compartir",
                subtitle: "Antes de que existiera el término 'open source', hubo personas que rechazaron fortunas para que el mundo tuviera acceso.",
                quote: "«El pueblo, diría yo. ¿Podrías patentar el sol?» — Jonas Salk",
                paragraphs: [
                    "Jonas Salk desarrolló la vacuna contra la polio y rechazó patentarla. Valía aproximadamente 7 mil millones de dólares. La polio fue erradicada.",
                    "Tim Berners-Lee inventó el World Wide Web y convenció a CERN de liberarlo al dominio público. Sin patentes, sin regalías: «Si hubiera tratado de exigir cuotas, no habría World Wide Web.»",
                    "Linus Torvalds escribió Linux como estudiante y eligió la licencia GPL. Hoy Linux corre servidores, teléfonos, la nube y la infraestructura del mundo entero: «Open source es la única forma correcta de hacer software.»",
                    "Ninguno eligió la fortuna. Todos eligieron el impacto."
                ]
            ),
            ManifestoChapter(
                id: "comunidad",
                badge: "CAPÍTULO II · IMPACTO HUMANO",
                title: "Cuando se cierra vs. La comunidad que salva vidas",
                subtitle: "No es ideología. Es aritmética. Y no es solo software.",
                quote: "«Personas que ven un problema y construyen la solución. Sin pedir permiso. Sin pedir dinero.»",
                paragraphs: [
                    "La diferencia entre la polio y el COVID es la diferencia entre abrir y cerrar. Salk regaló la vacuna de la polio y se erradicó. Las patentes cerradas en 2021 dejaron a solo el 3% de los países pobres con una dosis mientras el 60% de los países ricos estaba vacunado.",
                    "El 19 de septiembre de 2017, un terremoto de 7.1 sacudió Ciudad de México. En horas, la comunidad tech mexicana levantó plataformas para localizar desaparecidos, coordinar rescates y conectar voluntarios. No esperaron presupuesto. Actuaron.",
                    "La IA y los avances tecnológicos que usamos hoy nacieron en comunidades. Lo revolucionario hoy es publicar herramientas que funcionen para todos — pequeños y grandes.",
                    "Todos los que usamos código abierto tenemos una deuda. No se paga con dinero. Se paga compartiendo lo que sabemos con quien tengamos cerca. A escala humana. Volvamos a hacer público lo que siempre fue público."
                ]
            ),
            ManifestoChapter(
                id: "aaron-swartz",
                badge: "CAPÍTULO III · ARCHIVO HISTÓRICO (2008)",
                title: "Manifiesto por la Guerrilla del Acceso Abierto",
                subtitle: "Palabras escritas por Aaron Swartz en julio de 2008 en Eremo, Italia — más vigentes que nunca en 2026.",
                quote: "«Compartir no es inmoral, es un imperativo moral. Solo aquellos cegados por la codicia se negarían a dejar que un amigo hiciera una copia.» — Aaron Swartz",
                paragraphs: [
                    "Información es poder. Pero como todo poder, hay quienes quieren quedárselo para sí. Todo el patrimonio científico y cultural del mundo está siendo cada vez más digitalizado y bloqueado por un puñado de corporaciones privadas.",
                    "Aquellos con acceso a estos recursos (estudiantes, bibliotecarios, científicos) tienen un privilegio. No es necesario, y moralmente no se puede, mantener este privilegio para sí mismos. Tienes el deber de compartirlo con el mundo.",
                    "Con suficientes de nosotros, en todo el mundo, no solo enviaremos un fuerte mensaje en contra de la privatización del conocimiento, sino que lo convertiremos en una cosa del pasado. ¿Te nos unirás?"
                ]
            ),
            ManifestoChapter(
                id: "memoria-v1-v2",
                badge: "CAPÍTULO IV · ARQUITECTURA DAGGERSWIFT",
                title: "De DaggerSwift v1 (Sin IA) a DaggerSwift v2 (Motor DAG)",
                subtitle: "Orgullo de desarrollador: lo que construimos a pulso en 2024 y cómo evolucionó a un motor topológico en Swift 6.",
                quote: "«El grafo solo resuelve dependencias y valida precondiciones; el Coordinador decide la navegación.»",
                paragraphs: [
                    "Lo que nació sin IA en Dagger 1: La filosofía de módulos intercambiables (Demo vs DemoFaker), cero dependencias externas pesadas y semántica declarativa (@Singleton y @Provider).",
                    "Los dolores de cabeza de v1 en producción: @Singleton recreaba la instancia en cada lectura; @Provider mutaba un caché compartido produciendo estado fantasma; las propiedades estáticas atrapaban la memoria en RAM para siempre y no había protección ante Deep Links en frío.",
                    "El salto a DaggerSwift v2: ScopeContainer jerárquico (Global -> Session -> Module), autowiring con Parameter Packs (repeat each D) para que las clases de negocio tengan CERO decoradores, Nodos de Regla de Negocio (Feature Flags A->B) y Nodos de Precondición (ValidatedSession) con auditoría de fugas WeakObjectBox."
                ]
            )
        ]
    }
}
