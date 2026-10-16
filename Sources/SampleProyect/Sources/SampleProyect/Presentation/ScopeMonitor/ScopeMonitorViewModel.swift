//
//  ScopeMonitorViewModel.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · MVVM ViewModel
//  Gobierna la telemetría de memoria en tiempo real y el Stress Test de 25 scopes en ráfaga.
//

import Foundation
import SwiftUI
import DaggerSwift

@MainActor
public final class ScopeMonitorViewModel: ObservableObject {
    private let assembler: DaggerShowcaseAssembler

    public init(assembler: DaggerShowcaseAssembler) {
        self.assembler = assembler
    }

    public func runStressTest(coordinator: ShowcaseCoordinator) {
        var leaksFound = 0
        let repo = LiveGitHubRepository.flagshipDaggerRepo

        for _ in 0..<25 {
            if let (scope, _) = try? assembler.openRepositoryScope(for: repo, requiresAuth: false) {
                coordinator.totalScopesCreated += 1
                leaksFound += scope.teardown().count
                coordinator.totalScopesTornDown += 1
            }
        }
        coordinator.lastLeakAuditCount = leaksFound
        coordinator.appendLog(
            category: "StressTest",
            message: "⚡ Stress Test completado: 25 sub-scopes (`RepoDetailModule`) creados y destruidos en ráfaga. Fugas detectadas por WeakObjectBox: \(leaksFound)."
        )
    }
}
