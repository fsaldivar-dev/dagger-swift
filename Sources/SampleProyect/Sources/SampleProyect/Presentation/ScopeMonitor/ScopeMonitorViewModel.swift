//
//  ScopeMonitorViewModel.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · MVVM ViewModel
//  Gobierna la telemetría de memoria en tiempo real y el Stress Test de 25 scopes en ráfaga
//  utilizando directamente la API nativa de DaggerSwift (`ScopeContainer.makeChildScope`).
//

import Foundation
import SwiftUI
import DaggerSwift

@MainActor
public final class ScopeMonitorViewModel: ObservableObject {
    private let container: ScopeContainer

    public init(container: ScopeContainer) {
        self.container = container
    }

    public func runStressTest(coordinator: ShowcaseCoordinator) {
        var leaksFound = 0
        let repo = LiveGitHubRepository.flagshipDaggerRepo

        for _ in 0..<25 {
            let childScope = container.makeChildScope(for: RepoDetailModule.self)
            childScope.bindInstance(repo)
            if let inspector = try? RepoDetailInspector.resolve(in: childScope) {
                coordinator.totalScopesCreated += 1
                _ = consume inspector
                leaksFound += childScope.teardown().count
                coordinator.totalScopesTornDown += 1
            }
        }
        coordinator.lastLeakAuditCount = leaksFound
        coordinator.appendLog(
            category: "StressTest",
            message: "⚡ Stress Test completado: 25 sub-scopes (`RepoDetailModule`) creados y destruidos en ráfaga con DaggerSwift. Fugas detectadas por WeakObjectBox: \(leaksFound)."
        )
    }
}
