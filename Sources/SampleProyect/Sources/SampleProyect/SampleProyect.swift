//
//  SampleProyect.swift
//  SampleProyect
//
//  Arquitectura Modular SPM en 4 Capas Reales + DaggerSwift v2:
//
//  1. AppFoundation : Modelos compartidos (GitHubUserProfile, GitHubRepoItem) y Theme.
//  2. Core          : Contratos (Protocols), UseCases (@Inject), @Precondition y @BusinessRule.
//  3. Services      : Implementaciones Live/Faker y @Module de entornos.
//  4. Features      : Vistas y ViewModels MVVM (@Inject) desacoplados de Services.
//  5. SampleProyect : Punto de composición de la aplicación (ShowcaseRootView).
//

@_exported import Foundation
@_exported import SwiftUI
@_exported import DaggerSwift
@_exported import AppFoundation
@_exported import Core
@_exported import Services
@_exported import Features
