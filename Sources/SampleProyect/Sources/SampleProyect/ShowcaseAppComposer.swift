//
//  ShowcaseAppComposer.swift
//  SampleProyect · Composition Root (SOLID)
//
//  Abстраcción e implementación del Composer Inicial de la App.
//  - Cumple SRP: `ShowcaseRootView` solo renderiza UI y delega toda la creación de dependencias al Composer.
//  - Cumple OCP y DIP: Puedes cambiar el Composer en cualquier momento (por ejemplo entre
//    `ShowcaseAppComposer<LiveGitHubModule>` v1, `ShowcaseAppComposer<LiveGitHubModuleV2>` v2,
//    o un Composer de Preview/Test) sin modificar `ShowcaseRootView`.
//

import SwiftUI
import Core
import Services
import Features
import MultiCountryNewsDemo
import FintechMockupDemo

@MainActor
public protocol ShowcaseComposerProtocol {
    var composerTitle: String { get }
    func composeCountryNewsDemo() -> CountryNewsFeatureView
    func composeFintechDemo() -> FintechMockupFeatureView
    func composeGitHubFeedDemo() -> FeedView
}

@MainActor
public struct ShowcaseAppComposer<GitHubModule: GitHubServiceModuleContract>: ShowcaseComposerProtocol {
    public let initialCountry: SupportedCountry
    public let initialFintechPalette: FintechScope.Palette

    public var composerTitle: String {
        "Module(\(GitHubModule.moduleVersion)) · \(String(describing: GitHubModule.self))"
    }

    public init(
        initialCountry: SupportedCountry = .mexico,
        initialFintechPalette: FintechScope.Palette = .v2_0
    ) {
        self.initialCountry = initialCountry
        self.initialFintechPalette = initialFintechPalette
    }

    public func composeCountryNewsDemo() -> CountryNewsFeatureView {
        CountryNewsComposer.compose(initialCountry: initialCountry)
    }

    public func composeFintechDemo() -> FintechMockupFeatureView {
        FintechComposer.compose(initialPalette: initialFintechPalette)
    }

    public func composeGitHubFeedDemo() -> FeedView {
        GitHubFeedComposer.compose(module: GitHubModule.self)
    }
}
