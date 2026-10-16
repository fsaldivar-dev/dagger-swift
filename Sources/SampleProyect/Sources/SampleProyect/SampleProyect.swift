//
//  SampleProyect.swift
//  SampleProyect
//
//  Clean Architecture + MVVM + DaggerSwift v2 (Dagger 2 style)
//
//  Arquitectura:
//  ┌──────────────────────────────────────────────────────────────┐
//  │                        PRESENTATION                          │
//  │  ShowcaseRootView · RepoExplorerView · RepoDetailView        │
//  │  MVVM: HomeViewModel, RepoExplorerViewModel, etc.            │
//  └──────────────────────────────┬───────────────────────────────┘
//                                 │ consume
//  ┌──────────────────────────────▼───────────────────────────────┐
//  │                           DOMAIN                             │
//  │  Entities: GitHubUserProfile, GitHubRepoItem, Manifesto      │
//  │  Use Cases: GetProfileUseCase, GetRepositoriesUseCase        │
//  │  Preconditions: ValidatedSession                             │
//  │  Protocols: GitHubRepositoryProtocol, AuthRepositoryProtocol │
//  └──────────────────────────────▲───────────────────────────────┘
//                                 │ implementa
//  ┌──────────────────────────────┴───────────────────────────────┐
//  │                            DATA                              │
//  │  LiveGitHubRepository (REST API @fsaldivar-dev)              │
//  │  FakerGitHubRepository (Sandbox Offline Determinista)        │
//  │  AuthSessionRepository, ManifestoLocalRepository             │
//  └──────────────────────────────▲───────────────────────────────┘
//                                 │ cableado vía
//  ┌──────────────────────────────┴───────────────────────────────┐
//  │                        DAGGER GRAPH (DI)                     │
//  │  @Module: ShowcaseCoreModule, LiveGitHubModule, FakerModule  │
//  │  @Singleton · @BusinessRule (A->B) · @Precondition (Auth)    │
//  │  @Inject: RepoDetailInspector, PrivateVaultInteractor        │
//  └──────────────────────────────────────────────────────────────┘
//

@_exported import DaggerSwift
@_exported import Foundation
@_exported import SwiftUI
