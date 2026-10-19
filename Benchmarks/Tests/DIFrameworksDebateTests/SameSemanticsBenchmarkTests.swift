//
//  SameSemanticsBenchmarkTests.swift
//  DaggerSwiftBenchmarks
//
//  Round 4 · Comparación honesta con la MISMA semántica en todos los competidores:
//  `apiClient` @Singleton, `repository` @Scoped(BenchFeatureScope) cacheado, `BenchUseCase` transient.
//  (El "Explícito" del Round 3 crea repositorio y cliente nuevos en cada iteración: no es comparable.)
//
//  - DAG: `ScopeContainer` + `resolve` (detección de ciclos, precondiciones, búsqueda de recetas).
//  - Generado: `dagger-graph generate` → factories directas (Generated/DaggerGraph_BenchModuleV1*.swift).
//  - A mano: lo que escribiría una persona con la misma semántica (piso teórico).
//

import Foundation
import Testing
import DaggerSwift

@Suite("Round 4: Misma semántica — DAG vs código generado vs a mano")
struct SameSemanticsBenchmarkTests {

    @Test("Round 4: 10,000 resoluciones calientes + 1,000 arranques en frío, misma semántica")
    func sameSemanticsBenchmark() throws {
        let iterations = 10_000
        let coldIterations = 1_000
        let clock = ContinuousClock()

        // A. Motor DAG
        let root = ScopeContainer.root(modules: [BenchModuleV1.self])
        let feature = root.makeChildScope(for: BenchFeatureScope.self)
        _ = try feature.resolve(BenchUseCase.self)
        var dagSum = 0
        let dag = try clock.measure {
            for _ in 0..<iterations { dagSum &+= try feature.resolve(BenchUseCase.self).execute() }
        }

        // B. Código generado
        let graph = DaggerGraph_BenchModuleV1()
        let generatedFeature = graph.makeBenchFeatureScope()
        _ = try generatedFeature.benchUseCase()
        var generatedSum = 0
        let generated = try clock.measure {
            for _ in 0..<iterations { generatedSum &+= try generatedFeature.benchUseCase().execute() }
        }

        // C. A mano (misma semántica)
        let handRepository: any BenchRepositoryProtocol = BenchModuleV1.repository()
        var handSum = 0
        let hand = clock.measure {
            for _ in 0..<iterations { handSum &+= BenchUseCase(repository: handRepository).execute() }
        }

        // D. Round 3 "Explícito" (SIN caché: repositorio + cliente nuevos por iteración), como referencia.
        var explicitSum = 0
        let explicitNoCache = clock.measure {
            for _ in 0..<iterations { explicitSum &+= BenchFeatureScope.module(for: .v1_0).makeUseCase().execute() }
        }

        // Arranque en frío: construir el grafo + primera resolución.
        var coldSum = 0
        let dagCold = try clock.measure {
            for _ in 0..<coldIterations {
                let r = ScopeContainer.root(modules: [BenchModuleV1.self])
                coldSum &+= try r.makeChildScope(for: BenchFeatureScope.self).resolve(BenchUseCase.self).execute()
            }
        }
        let generatedCold = try clock.measure {
            for _ in 0..<coldIterations {
                coldSum &+= try DaggerGraph_BenchModuleV1().makeBenchFeatureScope().benchUseCase().execute()
            }
        }

        // Misma semántica: el repositorio @Scoped quedó cacheado en la caja del scope (no en la raíz).
        // (BenchRepositoryImpl es struct: no se puede comparar identidad con ===.)
        #expect(feature.isInstantiated((any BenchRepositoryProtocol).self))
        #expect(!root.isInstantiated((any BenchRepositoryProtocol).self))
        #expect(dagSum == iterations * 42)
        #expect(generatedSum == iterations * 42)
        #expect(handSum == iterations * 42)
        #expect(explicitSum == iterations * 42)
        #expect(coldSum == 2 * coldIterations * 42)

        func ms(_ d: Duration) -> Double {
            Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15
        }
        let floor = max(ms(hand), 0.0001)
        let rows: [(String, Double)] = [
            ("A mano (misma semántica)          ", ms(hand)),
            ("Generado (dagger-graph generate)  ", ms(generated)),
            ("Motor DAG (ScopeContainer.resolve)", ms(dag)),
            ("Round 3 'Explícito' SIN caché     ", ms(explicitNoCache)),
        ]
        var report = "\n╔══ Round 4 · Misma semántica · \(iterations) resoluciones calientes ══\n"
        for (name, value) in rows {
            report += String(format: "║ %@ | %8.3f ms (%6.1fx)\n", name as NSString, value, value / floor)
        }
        report += "╠══ Arranque en frío (\(coldIterations)× construir grafo + 1ª resolución) ══\n"
        report += String(format: "║ Motor DAG  %8.3f ms · Generado %8.3f ms (%.1fx)\n",
                         ms(dagCold), ms(generatedCold), ms(dagCold) / max(ms(generatedCold), 0.0001))
        report += "╚════════════════════════════════════════════════════════════\n"
        print(report)
    }
}
