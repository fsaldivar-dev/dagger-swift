//
//  DaggerSwiftTesting.swift
//  DaggerSwiftTesting
//
//  Herramientas oficiales de Testing para DaggerSwift v2 con Swift Testing (`import Testing`):
//  - @Tag semánticos para organizar pruebas de grafos en Xcode
//  - Snapshots JSON del grafo jerárquico (`GraphScopeSnapshot`)
//  - Auditoría comparativa de Precondiciones (Bloqueado vs Desbloqueado)
//  - Comparativa de Fallos (Cuando el grafo se rompe vs estado esperado)
//  - Attachments automáticos (`Attachment.record`) visibles en los reportes de Xcode
//

import Foundation
import Testing
import DaggerSwift

// MARK: - 1. Tags Oficiales para Swift Testing (`import Testing`)

public extension Tag {
    /// Pruebas que validan la topología y resolución del grafo DAG.
    @Tag static var graphTopology: Self

    /// Pruebas que validan precondiciones (`@Precondition` / sesiones / deep links).
    @Tag static var preconditionGuard: Self

    /// Pruebas que validan reglas de negocio dinámicas (`@BusinessRule` A -> B).
    @Tag static var businessRuleBranch: Self

    /// Pruebas que validan el ciclo de vida de Scopes (`teardown` y 0 memory leaks).
    @Tag static var scopeLifecycle: Self

    /// Pruebas comparativas donde provocamos un fallo en el grafo para verificar su protección.
    @Tag static var faultComparison: Self
}

// MARK: - 2. Modelos de Auditoría y Comparativa (JSON + Visual)

/// Comparativa paso a paso de una `@Precondition` (Antes de cumplirla vs Después de cumplirla).
public struct PreconditionAuditReport: Codable, Sendable, CustomTestStringConvertible {
    public struct StateRecord: Codable, Sendable {
        public let label: String
        public let status: String
        public let errorThrown: String?
        public let failureTrace: [String]
        public let activeInstancesInScope: Int
        public let scopeSnapshot: GraphScopeSnapshot
    }

    public let targetType: String
    public let preconditionNode: String
    public let whenBlocked: StateRecord
    public let whenUnlocked: StateRecord

    public func toJSONData() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    public func toJSONString() -> String {
        String(data: toJSONData(), encoding: .utf8) ?? "{}"
    }

    public var testDescription: String {
        let traceBlocked = whenBlocked.failureTrace.map(Self.shortName).joined(separator: " -> ❌ ")
        return """
        ╔══════════════════════════════════════════════════════════════════════╗
        ║ AUDITORÍA DE @PRECONDITION: \(Self.shortName(targetType))
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ 1. ESTADO SIN PRECONDICIÓN (\(whenBlocked.label)):
        ║    • Resultado     : \(whenBlocked.status)
        ║    • Rastro (DAG)  : \(traceBlocked)
        ║    • Motivo        : \(whenBlocked.errorThrown ?? "N/A")
        ║    • RAM en Scope  : \(whenBlocked.activeInstancesInScope) objetos (Protegido antes de instanciar)
        ╠──────────────────────────────────────────────────────────────────────╣
        ║ 2. ESTADO CON PRECONDICIÓN (\(whenUnlocked.label)):
        ║    • Resultado     : \(whenUnlocked.status)
        ║    • Rastro (DAG)  : \(Self.shortName(targetType)) -> ✅ \(Self.shortName(preconditionNode))
        ║    • RAM en Scope  : \(whenUnlocked.activeInstancesInScope) objeto(s) vivos en el Scope
        ╚══════════════════════════════════════════════════════════════════════╝
        """
    }

    private static func shortName(_ raw: String) -> String {
        raw.split(separator: ".").last.map(String.init) ?? raw
    }
}

/// Comparativa cuando el grafo se rompe (ej. dependencia faltante, ciclo A->B->A o violación de Scope).
public struct GraphFaultComparisonReport: Codable, Sendable, CustomTestStringConvertible {
    public let scenario: String
    public let requestedType: String
    public let expectedBehavior: String
    public let actualError: String
    public let brokenChain: [String]
    public let activeInstancesAfterAbort: Int
    public let graphSnapshot: GraphScopeSnapshot

    public func toJSONData() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    public func toJSONString() -> String {
        String(data: toJSONData(), encoding: .utf8) ?? "{}"
    }

    public var testDescription: String {
        let formattedChain = brokenChain.enumerated().map { idx, item in
            let short = item.split(separator: ".").last.map(String.init) ?? item
            return idx == brokenChain.count - 1 ? "💥 \(short) (ROTO AQUÍ)" : "✅ \(short)"
        }.joined(separator: " -> ")

        return """
        ╔══════════════════════════════════════════════════════════════════════╗
        ║ COMPARATIVA DE FALLO EN GRAFO: \(scenario)
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ • Nodo Solicitado  : \(requestedType)
        ║ • Esperado         : \(expectedBehavior)
        ║ • Error Recibido   : \(actualError)
        ║ • Camino del Grafo : \(formattedChain)
        ║ • Fugas en RAM     : \(activeInstancesAfterAbort) instancias residuales
        ╚══════════════════════════════════════════════════════════════════════╝
        """
    }
}

// MARK: - 3. Extensiones de Inspección y Attachments en `ScopeContainer`

public extension ScopeContainer {

    /// Exporta el grafo actual a JSON formateado y lo adjunta al reporte del test en Xcode (`Attachment.record`).
    @discardableResult
    func attachGraphJSON(named fileName: String = "dagger-graph-snapshot.json") -> GraphScopeSnapshot {
        let snap = self.snapshot()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snap),
           let jsonString = String(data: data, encoding: .utf8) {
            Attachment.record(jsonString, named: fileName)
        }
        return snap
    }

    /// Genera un diagrama Mermaid del grafo actual y lo adjunta al reporte del test en Xcode.
    @discardableResult
    func attachMermaidDiagram(named fileName: String = "dagger-graph-diagram.mmd") -> String {
        let snap = self.snapshot()
        var lines: [String] = ["flowchart TD"]
        Self.appendMermaidScope(snap, into: &lines)
        let diagram = lines.joined(separator: "\n")
        Attachment.record(diagram, named: fileName)
        return diagram
    }

    /// Audita una `@Precondition` comparando qué ocurre cuando está bloqueada vs cuando se cumple,
    /// y adjunta automáticamente el JSON comparativo y el resumen visual al test.
    @discardableResult
    func auditPrecondition<T, P: Precondition>(
        resolving target: T.Type,
        guardedBy precondition: P.Type,
        in childScopeBuilder: () -> ScopeContainer,
        unlockAction: () throws -> Void,
        attachmentPrefix: String = "precondition-audit"
    ) throws -> PreconditionAuditReport {
        // 1. Probar estado BLOQUEADO (cuando la precondición aún no se cumple)
        let blockedScope = childScopeBuilder()
        var caughtReason: String?
        do {
            _ = try blockedScope.resolve(T.self)
            Issue.record("Se esperaba que \(T.self) fuera bloqueado por la precondición \(P.self), pero se resolvió.")
        } catch let error as GraphError {
            caughtReason = error.description
        }
        let blockedTrace = blockedScope.lastFailureTrace
        let blockedSnap = blockedScope.snapshot()
        let blockedCount = blockedScope.activeInstanceCount
        blockedScope.teardown()

        // 2. Ejecutar la acción que desbloquea la precondición (ej. login)
        try unlockAction()

        // 3. Probar estado DESBLOQUEADO (ahora debe construir el objeto en el Scope)
        let unlockedScope = childScopeBuilder()
        _ = try unlockedScope.resolve(T.self)
        let unlockedSnap = unlockedScope.snapshot()
        let unlockedCount = unlockedScope.activeInstanceCount

        let report = PreconditionAuditReport(
            targetType: String(reflecting: T.self),
            preconditionNode: String(reflecting: P.self),
            whenBlocked: .init(
                label: "Sin Sesión / Precondición = nil",
                status: "❌ BLOQUEADO POR EL GRAFO",
                errorThrown: caughtReason,
                failureTrace: blockedTrace,
                activeInstancesInScope: blockedCount,
                scopeSnapshot: blockedSnap
            ),
            whenUnlocked: .init(
                label: "Con Sesión / Precondición Activa",
                status: "✅ RESUELTO EXITOSAMENTE",
                errorThrown: nil,
                failureTrace: [],
                activeInstancesInScope: unlockedCount,
                scopeSnapshot: unlockedSnap
            )
        )

        Attachment.record(report.toJSONString(), named: "\(attachmentPrefix).json")
        Attachment.record(report.testDescription, named: "\(attachmentPrefix)-summary.txt")

        unlockedScope.teardown()
        return report
    }

    /// Provoca y audita un fallo esperado en el grafo (ej. ciclo, dependencia faltante o scope inactivo),
    /// adjuntando el JSON y el rastro del eslabón roto al reporte del test.
    @discardableResult
    func auditExpectedFault<T>(
        scenario: String,
        resolving target: T.Type,
        expectedBehavior: String,
        attachmentPrefix: String = "fault-comparison"
    ) -> GraphFaultComparisonReport {
        var actualErrorText = "Ningún error (Inesperado)"
        do {
            _ = try self.resolve(T.self)
            Issue.record("Se esperaba que \(T.self) fallara en el escenario '\(scenario)', pero tuvo éxito.")
        } catch {
            actualErrorText = String(describing: error)
        }

        let report = GraphFaultComparisonReport(
            scenario: scenario,
            requestedType: String(reflecting: T.self),
            expectedBehavior: expectedBehavior,
            actualError: actualErrorText,
            brokenChain: self.lastFailureTrace,
            activeInstancesAfterAbort: self.activeInstanceCount,
            graphSnapshot: self.snapshot()
        )

        Attachment.record(report.toJSONString(), named: "\(attachmentPrefix).json")
        Attachment.record(report.testDescription, named: "\(attachmentPrefix)-trace.txt")
        return report
    }

    private static func appendMermaidScope(_ scope: GraphScopeSnapshot, into lines: inout [String]) {
        let cleanScope = shortName(scope.scope)
        lines.append("    subgraph \(cleanScope)[\"Scope: \(cleanScope) (vivos: \(scope.activeInstanceCount))\"]")
        for node in scope.nodes {
            let n = shortName(node.type)
            let stateIcon = node.isInstantiated ? "🟢" : "⚪️"
            lines.append("        \(n)[\"\(stateIcon) \(n) (\(node.kind))\"]")
        }
        lines.append("    end")
        for node in scope.nodes {
            let from = shortName(node.type)
            for dep in node.dependencies {
                let to = shortName(dep)
                lines.append("    \(from) --> \(to)")
            }
        }
        for child in scope.children {
            appendMermaidScope(child, into: &lines)
        }
    }

    private static func shortName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "any ", with: "")
            .split(separator: ".")
            .last
            .map(String.init) ?? raw
    }
}
