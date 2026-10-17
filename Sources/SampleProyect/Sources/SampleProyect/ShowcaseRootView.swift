//
//  ShowcaseRootView.swift
//  SampleProyect
//
//  Launcher Interactivo con Botones para elegir qué Demo App probar al compilar la App:
//  1. Multi-Country Login + News Home (MX, US, BR, FR en 4 idiomas)
//  2. Fintech Mockup Home (Paleta Module(0.1), Module(1.0), Module(2.0) + A/B Flags)
//  3. GitHub Developer Feed (@fsaldivar-dev + Sub-Scope de Detalle)
//

import SwiftUI
import DaggerSwift
import AppFoundation
import Core
import Services
import Features
import MultiCountryNewsDemo
import FintechMockupDemo

public enum ShowcaseDemoTab: Int, CaseIterable, Identifiable, Sendable {
    case multiCountryNews = 0
    case fintechAB = 1
    case githubFeed = 2

    public var id: Int { rawValue }
}

public struct ShowcaseRootView: View {
    @State private var activeDemo: ShowcaseDemoTab?
    @StateObject private var countryNewsVM: CountryNewsPortalViewModel
    @StateObject private var fintechVM: FintechMockupViewModel
    @StateObject private var githubFeedVM: FeedViewModel

    public init(
        environment: any GraphModule.Type = LiveGitHubModule.self,
        initialTab: ShowcaseDemoTab? = nil
    ) {
        self._activeDemo = State(initialValue: initialTab)

        // 1. Grafo Demo 1: Multi-Country Login + News (MX, US, BR, FR)
        let countryRoot = ScopeContainer.root(modules: [
            CountryNewsCoreModule.self,
            CountryAuthServiceModule.self
        ])
        let countryVM = try! CountryNewsPortalViewModel(rootContainer: countryRoot) { country in
            switch country {
            case .mexico: return MexicoNewsModule.self
            case .usa: return USANewsModule.self
            case .brazil: return BrazilNewsModule.self
            case .france: return FranceNewsModule.self
            }
        }
        _countryNewsVM = StateObject(wrappedValue: countryVM)

        // 2. Grafo Demo 2: Fintech Mockup (Paleta Module(0.1), Module(1.0), Module(2.0) + A/B Flags)
        let fintechRoot = ScopeContainer.root(modules: [
            FintechCoreModule.self,
            FintechSharedFlagsModule.self
        ])
        let finVM = try! FintechMockupViewModel(rootContainer: fintechRoot)
        _fintechVM = StateObject(wrappedValue: finVM)

        // 3. Grafo Demo 3: GitHub Social Developer Profile (@fsaldivar-dev)
        let githubContainer = ShowcaseCoreModule.buildGraph(including: [environment])
        let feedVM = try! FeedViewModel(from: githubContainer)
        _githubFeedVM = StateObject(wrappedValue: feedVM)
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

    // MARK: - Pantalla Inicial con Botones para elegir qué Demo App probar

    private var demoLauncherMenu: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DaggerSwift v2 · Demo Apps")
                            .font(.largeTitle.weight(.heavy))
                        Text("Selecciona qué aplicación demo quieres abrir para probar sus módulos, variantes y reglas de negocio:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 4)

                    demoLauncherButton(
                        badge: "TARGET: MultiCountryNewsDemo",
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
                        badge: "TARGET: FintechMockupDemo · Module(0.1 / 1.0 / 2.0)",
                        title: "2. App Mockup de Fintech (Variantes + A/B)",
                        subtitle: "Paleta interactiva @Module(0.1), @Module(1.0) y @Module(2.0) con includes + 2 switches A/B de @BusinessRule en la Home.",
                        icon: "creditcard.and.123",
                        gradient: [Color.purple, Color.indigo]
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            activeDemo = .fintechAB
                        }
                    }

                    demoLauncherButton(
                        badge: "TARGETS: Core + Services + Features",
                        title: "3. GitHub Developer Profile (@fsaldivar-dev)",
                        subtitle: "Feed social de repositorios conectado a GitHub REST API con Sub-Scope de detalle y auditoría de memoria ARC.",
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

                HStack {
                    Spacer()
                    Text("Abrir Demo App →")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.indigo.opacity(0.12)))
                        .foregroundStyle(.indigo)
                }
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

    // MARK: - Barra Superior para regresar al Selector o cambiar de Demo en un toque

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
            CountryNewsFeatureView(viewModel: countryNewsVM)
        case .fintechAB:
            NavigationStack {
                FintechMockupFeatureView(viewModel: fintechVM)
                    .navigationTitle("2. Fintech A/B & Module(0.1/1.0/2.0)")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        case .githubFeed:
            FeedView(viewModel: githubFeedVM)
        }
    }
}

public typealias DaggerShowcaseRootView = ShowcaseRootView
