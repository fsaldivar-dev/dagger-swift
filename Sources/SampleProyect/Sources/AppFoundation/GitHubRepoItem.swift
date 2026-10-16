//
//  GitHubRepoItem.swift
//  AppFoundation
//
//  Capa Foundation · Modelo compartido de repositorio de @fsaldivar-dev.
//

import Foundation

public struct GitHubRepoItem: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let description: String
    public let language: String
    public let stars: Int
    public let forks: Int
    public let openIssues: Int
    public let htmlURL: String
    public let defaultBranch: String
    public let isPrivateVault: Bool
    public let sizeKB: Int
    public let licenseName: String
    public let architectureNotes: String
    public let sampleFiles: [String]

    public init(
        id: Int,
        name: String,
        fullName: String,
        description: String,
        language: String,
        stars: Int,
        forks: Int,
        openIssues: Int,
        htmlURL: String,
        defaultBranch: String = "main",
        isPrivateVault: Bool = false,
        sizeKB: Int = 512,
        licenseName: String = "MIT",
        architectureNotes: String = "",
        sampleFiles: [String] = []
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.description = description
        self.language = language
        self.stars = stars
        self.forks = forks
        self.openIssues = openIssues
        self.htmlURL = htmlURL
        self.defaultBranch = defaultBranch
        self.isPrivateVault = isPrivateVault
        self.sizeKB = sizeKB
        self.licenseName = licenseName
        self.architectureNotes = architectureNotes
        self.sampleFiles = sampleFiles
    }

    public static let flagshipDaggerRepo = GitHubRepoItem(
        id: 87654321,
        name: "dagger-swift",
        fullName: "fsaldivar-dev/dagger-swift",
        description: "Motor de Grafo de Dependencias (DAG) y Scopes Jerárquicos en Swift 6. @Module, @Inject, @BusinessRule y @Precondition.",
        language: "Swift",
        stars: 42,
        forks: 5,
        openIssues: 0,
        htmlURL: "https://github.com/fsaldivar-dev/dagger-swift",
        defaultBranch: "main",
        isPrivateVault: false,
        sizeKB: 3420,
        licenseName: "GPL-3.0",
        architectureNotes: "Arquitectura modular SPM en 4 capas: AppFoundation, Core, Services y Features.",
        sampleFiles: [
            "Sources/DaggerSwift/GraphScope.swift",
            "Sources/DaggerSwift/ScopeContainer.swift",
            "Sources/DaggerSwift/Module.swift"
        ]
    )

    public static let curatedRepositories: [GitHubRepoItem] = [
        flagshipDaggerRepo,
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
            architectureNotes: "CLI nativo en Swift de un solo binario para automatizar el Simulador de iOS desde terminal.",
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
            architectureNotes: "Editor ligero de mockups para aplicaciones Tauri con kits de diseño e interfaz CLI.",
            sampleFiles: ["src/editor/CanvasStage.tsx", "src-tauri/src/main.rs", "cli/codaru-ai.ts"]
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
            isPrivateVault: true,
            sizeKB: 670,
            licenseName: "BSD-3-Clause",
            architectureNotes: "Requiere ValidatedSession (@Precondition) para abrir su inspección de arquitectura.",
            sampleFiles: ["src/planning/BoardView.tsx", "cli/tx-planner.ts"]
        )
    ]
}
