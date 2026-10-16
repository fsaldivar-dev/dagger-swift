//
//  ShowcaseRootView.swift
//  SampleProyect
//
//  Punto de entrada de la App Demo: construye el grafo raíz y presenta FeedView.
//

import SwiftUI
import DaggerSwift
import AppFoundation
import Core
import Services
import Features

public struct ShowcaseRootView: View {
    @StateObject private var viewModel: FeedViewModel

    public init(container: ScopeContainer) throws {
        let viewModel = try FeedViewModel(from: container)
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public init(environment: any GraphModule.Type = LiveGitHubModule.self) {
        let container = ShowcaseCoreModule.buildGraph(including: [environment])
        try! self.init(container: container)
    }

    public var body: some View {
        FeedView(viewModel: viewModel)
    }
}

public typealias DaggerShowcaseRootView = ShowcaseRootView
