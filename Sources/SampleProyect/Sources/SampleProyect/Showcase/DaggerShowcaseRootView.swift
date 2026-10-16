//
//  DaggerShowcaseRootView.swift
//  SampleProyect
//
//  Interfaz Multi-Plataforma (iPhone, iPad y macOS) para explorar el repositorio @fsaldivar-dev,
//  leer el Manifiesto, jugar con Deep Links, simular Autenticación (Precondition) y auditar Scopes en RAM.
//

import SwiftUI
import DaggerSwift

public struct DaggerShowcaseRootView: View {
    @StateObject private var coordinator: DaggerShowcaseCoordinator

    public init(assembler: DaggerShowcaseAssembler) {
        _coordinator = StateObject(wrappedValue: DaggerShowcaseCoordinator(assembler: assembler))
    }

    public init(environment: any GraphModule.Type = LiveGitHubModule.self) {
        let assembler = DaggerShowcaseAssembler(environment: environment)
        _coordinator = StateObject(wrappedValue: DaggerShowcaseCoordinator(assembler: assembler))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                profileHeaderBanner

                Picker("Sección", selection: $coordinator.selectedTab) {
                    ForEach(ShowcaseTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.systemIcon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                Group {
                    switch coordinator.selectedTab {
                    case .repositories:
                        repositoriesExplorerView
                    case .deepLinks:
                        deepLinksPlaygroundView
                    case .manifesto:
                        manifestoReaderView
                    case .graphMonitor:
                        graphMemoryMonitorView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await coordinator.refreshGitHubData() }
                    } label: {
                        Label("Sincronizar GitHub", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await coordinator.loadInitialData()
        }
        .onOpenURL { url in
            coordinator.handleDeepLinkURL(url)
        }
        .sheet(item: $coordinator.activeRepoSession, onDismiss: {
            coordinator.closeActiveRepoDetail()
        }) { session in
            RepoDetailScopedSheet(
                session: session,
                isAuthenticated: coordinator.isAuthenticated,
                onClose: { coordinator.closeActiveRepoDetail() }
            )
        }
        .sheet(item: $coordinator.activeVaultSession, onDismiss: {
            coordinator.closePrivateVault()
        }) { vaultSession in
            PrivateVaultScopedSheet(
                session: vaultSession,
                onClose: { coordinator.closePrivateVault() }
            )
        }
        .sheet(isPresented: $coordinator.showAuthGateSheet) {
            AuthPreconditionGateSheet(
                reason: coordinator.blockedPreconditionReason ?? "Ruta protegida por ValidatedSession",
                pendingDeepLink: coordinator.pendingDeepLink,
                onAuthenticate: { coordinator.simulateLogin() },
                onCancel: {
                    coordinator.showAuthGateSheet = false
                    coordinator.pendingDeepLink = nil
                }
            )
        }
    }

    // MARK: - 1. Banner de Perfil (@fsaldivar-dev) + Controles Rápidos del Grafo

    private var profileHeaderBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                AsyncImage(url: URL(string: coordinator.profile.avatarURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.indigo, .purple, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.18), lineWidth: 2))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(coordinator.profile.name)
                            .font(.headline.bold())
                        Text("@\(coordinator.profile.login)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(coordinator.profile.bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Label("\(coordinator.profile.publicRepos) repos", systemImage: "folder.fill")
                        Label("\(coordinator.profile.followers) followers", systemImage: "person.2.fill")
                        Label(coordinator.profile.location, systemImage: "location.fill")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Botón de Precondición: Simular Login / Logout
                Button {
                    if coordinator.isAuthenticated {
                        coordinator.simulateLogout()
                    } else {
                        coordinator.simulateLogin()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: coordinator.isAuthenticated ? "checkmark.shield.fill" : "lock.slash.fill")
                        Text(coordinator.isAuthenticated ? "Sesión Activa" : "Sin Sesión")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(coordinator.isAuthenticated ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                    )
                    .foregroundStyle(coordinator.isAuthenticated ? Color.green : Color.orange)
                }
                .buttonStyle(.plain)
            }

            // Barra de telemetría rápida del Grafo
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    statusChip(
                        icon: "cpu.fill",
                        text: coordinator.environmentTitle,
                        tint: .blue
                    )

                    Button {
                        coordinator.toggleFeatureFlagBentoV2(!coordinator.isBentoV2Enabled)
                    } label: {
                        statusChip(
                            icon: "flag.2.crossed.fill",
                            text: coordinator.currentStrategy.badgeTitle + " (Tocar para cambiar)",
                            tint: coordinator.isBentoV2Enabled ? .purple : .gray
                        )
                    }
                    .buttonStyle(.plain)

                    statusChip(
                        icon: "memorychip.fill",
                        text: "Scopes Creados: \(coordinator.totalScopesCreated) · Liberados: \(coordinator.totalScopesTornDown) · Leaks: \(coordinator.lastLeakAuditCount)",
                        tint: .teal
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(Color.secondary.opacity(0.06))
    }

    private func statusChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
        .foregroundStyle(tint)
    }

    // MARK: - 2. Tab 1: Explorador de Repositorios (Con Regla de Negocio A -> B)

    private var repositoriesExplorerView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Tarjeta de Regla de Negocio (Feature Flag A -> B)
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(.purple)
                            Text("Nodo de Regla de Negocio: \(coordinator.currentStrategy.variant.rawValue)")
                                .font(.subheadline.bold())
                        }
                        Text(coordinator.currentStrategy.accentDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Bento v2", isOn: Binding(
                        get: { coordinator.isBentoV2Enabled },
                        set: { coordinator.toggleFeatureFlagBentoV2($0) }
                    ))
                    .labelsHidden()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.08))
                )

                // Buscador
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar repositorio en @fsaldivar-dev (ej. dagger-swift, AutoPilot, Kairo)...", text: $coordinator.searchText)
                        .textFieldStyle(.plain)
                    if !coordinator.searchText.isEmpty {
                        Button {
                            coordinator.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.1))
                )

                if coordinator.isLoading {
                    ProgressView("Consultando grafo y repositorios de @fsaldivar-dev...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                }

                // Renderizado gobernado por el nodo RepoExplorerStrategyProtocol
                if coordinator.currentStrategy.usesBentoGrid {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 290, maximum: 520), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(coordinator.filteredRepositories) { repo in
                            bentoRepositoryCard(repo)
                        }
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(coordinator.filteredRepositories) { repo in
                            classicRepositoryRow(repo)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func bentoRepositoryCard(_ repo: GitHubRepoItem) -> some View {
        Button {
            coordinator.selectRepository(repo)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: repo.isPrivateVault ? "lock.shield.fill" : "shippingbox.fill")
                        .foregroundStyle(repo.isPrivateVault ? .orange : .indigo)
                    Text(repo.name)
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(repo.language)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.indigo.opacity(0.15)))
                        .foregroundStyle(.indigo)
                }

                Text(repo.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if !repo.architectureNotes.isEmpty {
                    Text(repo.architectureNotes)
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.8))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.08))
                        )
                }

                HStack(spacing: 12) {
                    Label("\(repo.stars)", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                    Label("\(repo.forks)", systemImage: "tuningfork")
                        .foregroundStyle(.secondary)
                    Label(repo.licenseName, systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.teal)
                    Spacer()
                    Text(repo.isPrivateVault ? "Exige ValidatedSession →" : "Crear Scope Hijo →")
                        .font(.caption2.bold())
                        .foregroundStyle(repo.isPrivateVault ? .orange : .indigo)
                }
                .font(.caption2)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondary.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(repo.isPrivateVault ? Color.orange.opacity(0.45) : Color.indigo.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func classicRepositoryRow(_ repo: GitHubRepoItem) -> some View {
        Button {
            coordinator.selectRepository(repo)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: repo.isPrivateVault ? "lock.fill" : "folder.fill")
                    .foregroundStyle(repo.isPrivateVault ? .orange : .blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.fullName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(repo.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(repo.language)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Tab 2: Laboratorio de Deep Links & Precondiciones

    private var deepLinksPlaygroundView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Tarjeta de Estado de Precondición
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: coordinator.isAuthenticated ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.title2)
                            .foregroundStyle(coordinator.isAuthenticated ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Precondición del Grafo: `ValidatedSession`")
                                .font(.headline)
                            Text(
                                coordinator.isAuthenticated
                                ? "Estado: ACTIVA (@\(coordinator.currentSession?.username ?? "fsaldivar-dev")). Los Deep Links protegidos se resolverán inmediatamente."
                                : "Estado: NO AUTENTICADO. Si disparas un Deep Link protegido, el Grafo lanzará `GraphError.unmetPrecondition` antes de reservar memoria y el Coordinador abrirá el Login Gate."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        Button {
                            coordinator.simulateLogin()
                        } label: {
                            Label("Autenticar como @fsaldivar-dev", systemImage: "person.badge.key.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.2)))
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                        .disabled(coordinator.isAuthenticated)

                        Button {
                            coordinator.simulateLogout()
                        } label: {
                            Label("Cerrar Sesión (Invalidar Nodo)", systemImage: "lock.rotation")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.15)))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(!coordinator.isAuthenticated)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.secondary.opacity(0.08))
                )

                Text("Simulador de Deep Links (`daggerswift://`)")
                    .font(.headline)

                let presets: [ShowcaseDeepLink] = [
                    .privateVault,
                    .repoDetail(name: "dagger-swift", requiresAuth: true),
                    .repoDetail(name: "AutoPilot", requiresAuth: false),
                    .repoDetail(name: "codaru-mockup", requiresAuth: false),
                    .manifesto(chapterID: "aaron-swartz"),
                    .manifesto(chapterID: "memoria-v1-v2"),
                    .featureFlag(enableBentoV2: !coordinator.isBentoV2Enabled)
                ]

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260, maximum: 500), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(presets) { link in
                        Button {
                            coordinator.handleDeepLink(link)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(link.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text(link.urlString)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.indigo)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.indigo.opacity(0.25), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                Text("Bitácora en Vivo: Grafo vs. Coordinador")
                    .font(.headline)

                ForEach(coordinator.eventLogs.prefix(8)) { log in
                    eventLogRow(log)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 4. Tab 3: Lector del Manifiesto & Memoria Dagger v1/v2

    private var manifestoReaderView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(coordinator.chapters) { chapter in
                            let isSelected = coordinator.selectedChapterID == chapter.id
                            Button {
                                coordinator.selectedChapterID = chapter.id
                            } label: {
                                Text(chapter.title)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.indigo : Color.secondary.opacity(0.12))
                                    )
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let activeChapter = coordinator.chapters.first(where: { $0.id == coordinator.selectedChapterID }) ?? coordinator.chapters.first {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(activeChapter.badge)
                            .font(.caption2.bold())
                            .foregroundStyle(.indigo)

                        Text(activeChapter.title)
                            .font(.title2.bold())

                        Text(activeChapter.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(activeChapter.quote)
                            .font(.callout.italic().weight(.medium))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.indigo.opacity(0.09))
                            )

                        ForEach(activeChapter.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.06))
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - 5. Tab 4: Monitor del Grafo DAG & Memoria (WeakObjectBox)

    private var graphMemoryMonitorView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    metricCard(
                        title: "Scopes Creados",
                        value: "\(coordinator.totalScopesCreated)",
                        subtitle: "Global + Módulos Hijos",
                        tint: .indigo
                    )
                    metricCard(
                        title: "Scopes Liberados",
                        value: "\(coordinator.totalScopesTornDown)",
                        subtitle: "teardown() ejecutados",
                        tint: .teal
                    )
                    metricCard(
                        title: "Fugas en RAM",
                        value: "\(coordinator.lastLeakAuditCount)",
                        subtitle: "Auditoría WeakObjectBox",
                        tint: .green
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Prueba de Estrés de Memoria (Creación y Destrucción de Sub-Scopes)")
                        .font(.headline)
                    Text("Instancia 25 sub-scopes hijos (`RepoDetailModule`) con sus respectivos `RepoDetailInspector`, ejecuta `teardown()` y verifica mediante `WeakObjectBox` que ARC libere el 100% de las referencias.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        coordinator.runMemoryStressTest()
                    } label: {
                        Label("Ejecutar Stress Test (25 Scopes en Ráfaga)", systemImage: "bolt.shield.fill")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.07)))

                Text("Historial Completo de Eventos del Grafo")
                    .font(.headline)

                ForEach(coordinator.eventLogs) { log in
                    eventLogRow(log)
                }
            }
            .padding(16)
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(tint)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tint.opacity(0.1))
        )
    }

    private func eventLogRow(_ log: ScopeEventLog) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(log.category)
                .font(.caption2.bold().monospaced())
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(log.isError ? Color.red.opacity(0.18) : Color.indigo.opacity(0.15))
                )
                .foregroundStyle(log.isError ? .red : .indigo)

            Text(log.message)
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}

// MARK: - Sub-Vista Scoped: Detalle de Repositorio (RepoDetailModule)

struct RepoDetailScopedSheet: View {
    let session: ActiveRepoSession
    let isAuthenticated: Bool
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Banner del Sub-Scope activo en RAM
                    HStack {
                        Image(systemName: "memorychip.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scope Activo en RAM: `RepoDetailModule`")
                                .font(.caption.bold())
                            Text("Instancia: `\(session.inspector.instanceID)` · Objetos vivos en este scope: \(session.scope.activeInstanceCount)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.12)))

                    Text(session.inspector.repo.fullName)
                        .font(.title2.bold())

                    Text(session.inspector.repo.description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        Label("\(session.inspector.repo.stars) Stars", systemImage: "star.fill")
                        Label("\(session.inspector.repo.forks) Forks", systemImage: "tuningfork")
                        Label(session.inspector.repo.language, systemImage: "chevron.left.forwardslash.chevron.right")
                        Label("\(session.inspector.repo.sizeKB) KB", systemImage: "externaldrive.fill")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.indigo)

                    if !session.inspector.repo.architectureNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notas de Arquitectura")
                                .font(.headline)
                            Text(session.inspector.repo.architectureNotes)
                                .font(.callout)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
                    }

                    if !session.inspector.repo.sampleFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Árbol de Archivos Destacados")
                                .font(.headline)
                            ForEach(session.inspector.repo.sampleFiles, id: \.self) { file in
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundStyle(.indigo)
                                    Text(file)
                                        .font(.caption.monospaced())
                                    Spacer()
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
                            }
                        }
                    }

                    if let url = URL(string: session.inspector.repo.htmlURL) {
                        Link(destination: url) {
                            Label("Abrir en GitHub (\(session.inspector.repo.htmlURL))", systemImage: "safari.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo.opacity(0.15)))
                        }
                    }

                    Button(role: .destructive) {
                        onClose()
                    } label: {
                        Label("Cerrar Pantalla y Ejecutar `RepoDetailModule.teardown()`", systemImage: "trash.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.16)))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .navigationTitle(session.inspector.repo.name)
        }
        .frame(minWidth: 360, minHeight: 440)
    }
}

// MARK: - Sub-Vista Scoped: Bóveda Privada (PrivateVaultModule)

struct PrivateVaultScopedSheet: View {
    let session: ActiveVaultSession
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lock.open.shield.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Bóveda Privada Desbloqueada")
                            .font(.headline)
                        Text("Precondición `ValidatedSession` verificada para @\(session.vault.session.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                ForEach(session.vault.secretKeys, id: \.self) { secret in
                    Text(secret)
                        .font(.caption.monospaced())
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Label("Cerrar Bóveda y Destruir `PrivateVaultModule` en RAM", systemImage: "xmark.shield.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.2)))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationTitle("PrivateVaultModule")
        }
        .frame(minWidth: 360, minHeight: 360)
    }
}

// MARK: - Auth Precondition Gate Sheet

struct AuthPreconditionGateSheet: View {
    let reason: String
    let pendingDeepLink: ShowcaseDeepLink?
    let onAuthenticate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "hand.raised.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Precondición del Grafo No Cumplida")
                .font(.title3.bold())

            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let pending = pendingDeepLink {
                VStack(spacing: 4) {
                    Text("Deep Link en espera de autenticación:")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text(pending.urlString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.indigo)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo.opacity(0.1)))
            }

            HStack(spacing: 12) {
                Button("Cancelar") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button {
                    onAuthenticate()
                } label: {
                    Label("Autenticar como @fsaldivar-dev y Continuar", systemImage: "key.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 320)
    }
}
