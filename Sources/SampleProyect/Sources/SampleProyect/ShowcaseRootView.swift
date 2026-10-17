//
//  ShowcaseRootView.swift
//  SampleProyect
//
//  Punto de entrada de los 3 Demos interactivos de DaggerSwift v2:
//  1. Multi-Country Login + News Home (MX, US, BR, FR en 4 idiomas con @Module(scope:) + @Precondition)
//  2. Fintech Mockup Home (Variantes V1->V2 con @Module(includes:) + @BusinessRule A/B Flags)
//  3. GitHub Developer Feed (@fsaldivar-dev + Sub-Scope de Detalle)
//

import SwiftUI
import DaggerSwift
import AppFoundation
import Core
import Services
import Features

public enum ShowcaseDemoTab: Int, CaseIterable, Sendable {
    case multiCountryNews = 0
    case fintechAB = 1
    case githubFeed = 2
}

public struct ShowcaseRootView: View {
    @State private var selectedTab: ShowcaseDemoTab
    @StateObject private var countryNewsVM: CountryNewsPortalViewModel
    @StateObject private var fintechVM: FintechMockupViewModel
    @StateObject private var githubFeedVM: FeedViewModel

    public init(
        environment: any GraphModule.Type = LiveGitHubModule.self,
        initialTab: ShowcaseDemoTab = .multiCountryNews
    ) {
        self._selectedTab = State(initialValue: initialTab)

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

        // 2. Grafo Demo 2: Fintech Mockup (V1 -> V2 + A/B Feature Flags)
        let fintechRoot = ScopeContainer.root(modules: [
            FintechCoreModule.self,
            FintechSharedFlagsModule.self
        ])
        let finVM = try! FintechMockupViewModel(
            rootContainer: fintechRoot,
            v1Module: FintechModuleV1.self,
            v2Module: FintechModuleV2.self
        )
        _fintechVM = StateObject(wrappedValue: finVM)

        // 3. Grafo Demo 3: GitHub Social Developer Profile (@fsaldivar-dev)
        let githubContainer = ShowcaseCoreModule.buildGraph(including: [environment])
        let feedVM = try! FeedViewModel(from: githubContainer)
        _githubFeedVM = StateObject(wrappedValue: feedVM)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            CountryNewsFeatureView(viewModel: countryNewsVM)
                .tabItem {
                    Label("1. Multi-Country", systemImage: "globe.americas.fill")
                }
                .tag(ShowcaseDemoTab.multiCountryNews)

            FintechMockupFeatureView(viewModel: fintechVM)
                .tabItem {
                    Label("2. Fintech A/B", systemImage: "creditcard.fill")
                }
                .tag(ShowcaseDemoTab.fintechAB)

            FeedView(viewModel: githubFeedVM)
                .tabItem {
                    Label("3. GitHub Feed", systemImage: "person.crop.circle.badge.checkmark")
                }
                .tag(ShowcaseDemoTab.githubFeed)
        }
    }
}

public typealias DaggerShowcaseRootView = ShowcaseRootView
