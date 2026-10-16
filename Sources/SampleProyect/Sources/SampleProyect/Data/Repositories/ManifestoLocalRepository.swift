//
//  ManifestoLocalRepository.swift
//  SampleProyect
//
//  Clean Architecture · Data Layer · Repository Implementation
//  Provee los capítulos del Manifiesto Open Source y la Memoria de Arquitectura de DaggerSwift.
//

import Foundation

public final class ManifestoLocalRepository: ManifestoRepositoryProtocol, Sendable {
    public init() {}

    public func getChapters() -> [ManifestoChapter] {
        [
            ManifestoChapter(
                id: "gigantes",
                badge: "CAPÍTULO I · MANIFIESTO",
                title: "Los gigantes que eligieron compartir",
                subtitle: "Antes de que existiera el término 'open source', hubo personas que rechazaron fortunas para que el mundo tuviera acceso.",
                quote: "«El pueblo, diría yo. ¿Podrías patentar el sol?» — Jonas Salk",
                paragraphs: [
                    "Jonas Salk desarrolló la vacuna contra la polio y rechazó patentarla. Valía aproximadamente 7 mil millones de dólares. La polio fue erradicada.",
                    "Tim Berners-Lee inventó el World Wide Web y convenció a CERN de liberarlo al dominio público. Sin patentes, sin regalías: «Si hubiera tratado de exigir cuotas, no habría World Wide Web.»",
                    "Linus Torvalds escribió Linux como estudiante y eligió la licencia GPL. Hoy Linux corre servidores, teléfonos, la nube y la infraestructura del mundo entero: «Open source es la única forma correcta de hacer software.»",
                    "Ninguno eligió la fortuna. Todos eligieron el impacto."
                ]
            ),
            ManifestoChapter(
                id: "comunidad",
                badge: "CAPÍTULO II · IMPACTO HUMANO",
                title: "Cuando se cierra vs. La comunidad que salva vidas",
                subtitle: "No es ideología. Es aritmética. Y no es solo software.",
                quote: "«Personas que ven un problema y construyen la solución. Sin pedir permiso. Sin pedir dinero.»",
                paragraphs: [
                    "La diferencia entre la polio y el COVID es la diferencia entre abrir y cerrar. Salk regaló la vacuna de la polio y se erradicó. Las patentes cerradas en 2021 dejaron a solo el 3% de los países pobres con una dosis mientras el 60% de los países ricos estaba vacunado.",
                    "El 19 de septiembre de 2017, un terremoto de 7.1 sacudió Ciudad de México. En horas, la comunidad tech mexicana levantó plataformas para localizar desaparecidos, coordinar rescates y conectar voluntarios. No esperaron presupuesto. Actuaron.",
                    "La IA y los avances tecnológicos que usamos hoy nacieron en comunidades. Lo revolucionario hoy es publicar herramientas que funcionen para todos — pequeños y grandes.",
                    "Todos los que usamos código abierto tenemos una deuda. No se paga con dinero. Se paga compartiendo lo que sabemos con quien tengamos cerca. A escala humana. Volvamos a hacer público lo que siempre fue público."
                ]
            ),
            ManifestoChapter(
                id: "aaron-swartz",
                badge: "CAPÍTULO III · ARCHIVO HISTÓRICO (2008)",
                title: "Manifiesto por la Guerrilla del Acceso Abierto",
                subtitle: "Palabras escritas por Aaron Swartz en julio de 2008 en Eremo, Italia — más vigentes que nunca en 2026.",
                quote: "«Compartir no es inmoral, es un imperativo moral. Solo aquellos cegados por la codicia se negarían a dejar que un amigo hiciera una copia.» — Aaron Swartz",
                paragraphs: [
                    "Información es poder. Pero como todo poder, hay quienes quieren quedárselo para sí. Todo el patrimonio científico y cultural del mundo está siendo cada vez más digitalizado y bloqueado por un puñado de corporaciones privadas.",
                    "Aquellos con acceso a estos recursos (estudiantes, bibliotecarios, científicos) tienen un privilegio. No es necesario, y moralmente no se puede, mantener este privilegio para sí mismos. Tienes el deber de compartirlo con el mundo.",
                    "Con suficientes de nosotros, en todo el mundo, no solo enviaremos un fuerte mensaje en contra de la privatización del conocimiento, sino que lo convertiremos en una cosa del pasado. ¿Te nos unirás?"
                ]
            ),
            ManifestoChapter(
                id: "memoria-v1-v2",
                badge: "CAPÍTULO IV · ARQUITECTURA DAGGERSWIFT",
                title: "De DaggerSwift v1 (Sin IA) a DaggerSwift v2 (Motor DAG)",
                subtitle: "Orgullo de desarrollador: lo que construimos a pulso en 2024 y cómo evolucionó a un motor topológico en Swift 6.",
                quote: "«El grafo solo resuelve dependencias y valida precondiciones; el Coordinador decide la navegación.»",
                paragraphs: [
                    "Lo que nació sin IA en Dagger 1: La filosofía de módulos intercambiables (Demo vs DemoFaker), cero dependencias externas pesadas y semántica declarativa (@Singleton y @Provider).",
                    "Los dolores de cabeza de v1 en producción: @Singleton recreaba la instancia en cada lectura; @Provider mutaba un caché compartido produciendo estado fantasma; las propiedades estáticas atrapaban la memoria en RAM para siempre y no había protección ante Deep Links en frío.",
                    "El salto a DaggerSwift v2: ScopeContainer jerárquico (Global -> Session -> Module), autowiring con Parameter Packs (repeat each D) para que las clases de negocio tengan CERO decoradores, Nodos de Regla de Negocio (Feature Flags A->B) y Nodos de Precondición (ValidatedSession) con auditoría de fugas WeakObjectBox."
                ]
            )
        ]
    }
}

// Retro-compatibilidad con código v2 previo
public typealias ManifestoRepository = ManifestoLocalRepository
extension ManifestoLocalRepository {
    public func fetchChapters() -> [ManifestoChapter] { getChapters() }
}
