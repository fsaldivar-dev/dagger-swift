//
//  ShowcaseRootView.swift
//  SampleProyect
//
//  Selector Raíz de las 3 Demos (Cumple SOLID + Plug & UnPlug):
//  - Cada Demo se conecta como una pieza independiente (UnCoupled).
//  - Permite alternar en caliente entre `LiveGitHubModule` (v1.0) y `LiveGitHubModuleV2` (v2.0).
//

import SwiftUI
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
    @State private var useGitHubV2Module: Bool = false

    public init(initialTab: ShowcaseDemoTab? = nil, useGitHubV2Module: Bool = false) {
        self._activeDemo = State(initialValue: initialTab)
        self._useGitHubV2Module = State(initialValue: useGitHubV2Module)
    }

    public init<M: GitHubServiceModuleContract>(environment: M.Type, initialTab: ShowcaseDemoTab? = nil) {
        self._activeDemo = State(initialValue: initialTab)
        self._useGitHubV2Module = State(initialValue: M.moduleVersion == "2.0")
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

    private var demoLauncherMenu: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("DaggerSwift v2 · Demo Apps").font(.largeTitle.weight(.heavy))
                    Text("Clean Architecture + MVVM + SOLID + Plug & UnPlug Modular:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    demoLauncherButton(
                        badge: "TARGET: MultiCountryNewsDemo · Plug & UnPlug (MX / US / BR / FR)",
                        title: "1. Login Multi-Country + Noticias",
                        subtitle: "Conecta y desconecta en vivo los módulos de México, USA, Brasil y Francia con @Precondition.",
                        icon: "globe.americas.fill",
                        gradient: [.indigo, .blue]
                    ) { activeDemo = .multiCountryNews }

                    demoLauncherButton(
                        badge: "TARGET: FintechMockupDemo · @Scope(0.1 / 1.0 / 2.0)",
                        title: "2. App Mockup de Fintech (Variantes + A/B)",
                        subtitle: "Evolución Plug & UnPlug entre Module(0.1), Module(1.0) y Module(2.0) + @BusinessRule A/B.",
                        icon: "creditcard.and.123",
                        gradient: [.purple, .indigo]
                    ) { activeDemo = .fintechAB }

                    demoLauncherButton(
                        badge: "TARGET: Core + Services + Features · Module(\(useGitHubV2Module ? "2.0" : "1.0"))",
                        title: "3. GitHub Developer Profile (@fsaldivar-dev)",
                        subtitle: "Capas separadas en targets SPM con Sub-Scope de detalle y auditoría de memoria.",
                        icon: "person.crop.circle.badge.checkmark",
                        gradient: [.teal, .blue]
                    ) { activeDemo = .githubFeed }

                    Toggle("Plug & UnPlug Demo 3: Usar `LiveGitHubModuleV2` (Module 2.0)", isOn: $useGitHubV2Module)
                        .font(.caption.weight(.bold))
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.showcaseCardBackground))
                }
                .padding(20)
            }
            .navigationTitle("Selector de Demos")
        }
    }

    private func demoLauncherButton(
        badge: String, title: String, subtitle: String, icon: String, gradient: [Color], action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge).font(.caption2.weight(.heavy).monospaced()).foregroundStyle(.indigo)
                        Text(title).font(.headline.weight(.bold)).foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill").foregroundStyle(.indigo)
                }
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.showcaseCardBackground))
        }
        .buttonStyle(.plain)
    }

    private func topDemoSwitcherBar(current: ShowcaseDemoTab) -> some View {
        HStack(spacing: 8) {
            Button("⬅ Demos") { activeDemo = nil }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.indigo.opacity(0.14)))
                .foregroundStyle(.indigo)
                .buttonStyle(.plain)
            Spacer()
            quickTabPill(title: "🌎 Multi-Country", tab: .multiCountryNews, current: current)
            quickTabPill(title: "💳 Fintech", tab: .fintechAB, current: current)
            quickTabPill(title: "🐙 GitHub", tab: .githubFeed, current: current)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.showcaseCardBackground)
    }

    private func quickTabPill(title: String, tab: ShowcaseDemoTab, current: ShowcaseDemoTab) -> some View {
        let isSelected = tab == current
        return Button(title) { activeDemo = tab }
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(isSelected ? Color.indigo : Color.showcaseSubtleFill))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .buttonStyle(.plain)
    }

    @ViewBuilder
    private func selectedDemoView(for demo: ShowcaseDemoTab) -> some View {
        switch demo {
        case .multiCountryNews:
            CountryNewsFeatureView()
        case .fintechAB:
            NavigationStack { FintechMockupFeatureView().navigationTitle("2. Fintech A/B & Module(0.1/1.0/2.0)") }
        case .githubFeed:
            useGitHubV2Module ? FeedView(module: LiveGitHubModuleV2.self) : FeedView(module: LiveGitHubModule.self)
        }
    }
}

public typealias DaggerShowcaseRootView = ShowcaseRootView
