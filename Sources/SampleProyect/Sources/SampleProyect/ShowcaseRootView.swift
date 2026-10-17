//
//  ShowcaseRootView.swift
//  SampleProyect
//
//  Vista Raíz desacoplada (Cumple SOLID):
//  - SRP: Solo presenta el menú de navegación de las Demos; no instancia UseCases, Repositorios ni ViewModels.
//  - OCP / DIP: Recibe un `any ShowcaseComposerProtocol` intercambiable en cualquier momento
//    (por ejemplo `ShowcaseAppComposer<LiveGitHubModule>()` o `ShowcaseAppComposer<LiveGitHubModuleV2>()`).
//

import SwiftUI
import AppFoundation
import Core
import Services

public enum ShowcaseDemoTab: Int, CaseIterable, Identifiable, Sendable {
    case multiCountryNews = 0
    case fintechAB = 1
    case githubFeed = 2

    public var id: Int { rawValue }
}

public struct ShowcaseRootView: View {
    @State private var composer: any ShowcaseComposerProtocol
    @State private var activeDemo: ShowcaseDemoTab?
    @State private var useLoginV2Composer: Bool = false

    public init(
        composer: any ShowcaseComposerProtocol = ShowcaseAppComposer<LiveGitHubModule>(),
        initialTab: ShowcaseDemoTab? = nil
    ) {
        self._composer = State(initialValue: composer)
        self._activeDemo = State(initialValue: initialTab)
    }

    public init<M: GitHubServiceModuleContract>(
        environment: M.Type,
        initialTab: ShowcaseDemoTab? = nil
    ) {
        self.init(
            composer: ShowcaseAppComposer<M>(),
            initialTab: initialTab
        )
    }

    public var body: some View {
        if let selected = activeDemo {
            VStack(spacing: 0) {
                topDemoSwitcherBar(current: selected)
                Divider()
                selectedDemoView(for: selected)
            }
        } else {
            demoLauncherMenu
        }
    }

    // MARK: - Selector de Demos + Switch de Composer en Vivo

    private var demoLauncherMenu: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DaggerSwift v2 · Demo Apps")
                            .font(.largeTitle.weight(.heavy))
                        Text("Selecciona qué aplicación demo quieres abrir. Cada flujo es ensamblado por su propio Composer siguiendo Clean Architecture + MVVM:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    composerSwitcherBanner

                    demoLauncherButton(
                        badge: "COMPOSER: CountryNewsComposer",
                        title: "1. Login Multi-Country + Noticias",
                        subtitle: "Variantes hermanas 🇲🇽 Español, 🇺🇸 English, 🇧🇷 Português y 🇫🇷 Français con @Module(scope:) y @Precondition de sesión.",
                        icon: "globe.americas.fill",
                        gradient: [Color.indigo, Color.blue]
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            activeDemo = .multiCountryNews
                        }
                    }

                    demoLauncherButton(
                        badge: "COMPOSER: FintechComposer · @Scope(0.1 / 1.0 / 2.0)",
                        title: "2. App Mockup de Fintech (Variantes + A/B)",
                        subtitle: "Paleta @Scope sintetizada (Module(0.1), Module(1.0), Module(2.0)) + switches A/B de @BusinessRule en la Home.",
                        icon: "creditcard.and.123",
                        gradient: [Color.purple, Color.indigo]
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            activeDemo = .fintechAB
                        }
                    }

                    demoLauncherButton(
                        badge: "COMPOSER: GitHubFeedComposer · \(composer.composerTitle)",
                        title: "3. GitHub Developer Profile (@fsaldivar-dev)",
                        subtitle: "Feed social de repositorios conectado a GitHub REST API con Sub-Scope de detalle.",
                        icon: "person.crop.circle.badge.checkmark",
                        gradient: [Color.teal, Color.blue]
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            activeDemo = .githubFeed
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Selector de Demos")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var composerSwitcherBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Composer Activo: \(composer.composerTitle)")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(.indigo)
                Text("Puedes cambiar el Composer inicial en caliente (Login V1 vs OAuth V2):")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                useLoginV2Composer.toggle()
                composer = useLoginV2Composer
                    ? ShowcaseAppComposer<LiveGitHubModuleV2>()
                    : ShowcaseAppComposer<LiveGitHubModule>()
            } label: {
                Text(useLoginV2Composer ? "Usando V2" : "Cambiar a V2")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.indigo.opacity(0.14)))
                    .foregroundStyle(.indigo)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.showcaseCardBackground)
        )
    }

    private func demoLauncherButton(
        badge: String,
        title: String,
        subtitle: String,
        icon: String,
        gradient: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge)
                            .font(.caption2.weight(.heavy).monospaced())
                            .foregroundStyle(.indigo)
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.showcaseCardBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Barra Superior

    private func topDemoSwitcherBar(current: ShowcaseDemoTab) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    activeDemo = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Demos")
                        .fontWeight(.bold)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.indigo.opacity(0.14)))
                .foregroundStyle(.indigo)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                quickTabPill(title: "🌎 Multi-Country", tab: .multiCountryNews, current: current)
                quickTabPill(title: "💳 Fintech", tab: .fintechAB, current: current)
                quickTabPill(title: "🐙 GitHub", tab: .githubFeed, current: current)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.showcaseCardBackground)
    }

    private func quickTabPill(title: String, tab: ShowcaseDemoTab, current: ShowcaseDemoTab) -> some View {
        let isSelected = tab == current
        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                activeDemo = tab
            }
        } label: {
            Text(title)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isSelected ? Color.indigo : Color.showcaseSubtleFill)
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func selectedDemoView(for demo: ShowcaseDemoTab) -> some View {
        switch demo {
        case .multiCountryNews:
            composer.composeCountryNewsDemo()
        case .fintechAB:
            NavigationStack {
                composer.composeFintechDemo()
                    .navigationTitle("2. Fintech A/B & Module(0.1/1.0/2.0)")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        case .githubFeed:
            composer.composeGitHubFeedDemo()
        }
    }
}

public typealias DaggerShowcaseRootView = ShowcaseRootView
