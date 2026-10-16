//
//  GitHubRepoItem.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Entity
//  Representa un repositorio open source de @fsaldivar-dev.
//

import Foundation

public struct GitHubRepoItem: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let description: String
    public let language: String
    public let stars: Int
    public let forks: Int
    public let openIssues: Int
    public let htmlURL: String
    public let defaultBranch: String
    public let isPrivateVault: Bool
    public let sizeKB: Int
    public let licenseName: String
    public let architectureNotes: String
    public let sampleFiles: [String]

    public init(
        id: Int,
        name: String,
        fullName: String,
        description: String,
        language: String,
        stars: Int,
        forks: Int,
        openIssues: Int,
        htmlURL: String,
        defaultBranch: String = "main",
        isPrivateVault: Bool = false,
        sizeKB: Int = 512,
        licenseName: String = "MIT",
        architectureNotes: String = "",
        sampleFiles: [String] = []
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.description = description
        self.language = language
        self.stars = stars
        self.forks = forks
        self.openIssues = openIssues
        self.htmlURL = htmlURL
        self.defaultBranch = defaultBranch
        self.isPrivateVault = isPrivateVault
        self.sizeKB = sizeKB
        self.licenseName = licenseName
        self.architectureNotes = architectureNotes
        self.sampleFiles = sampleFiles
    }
}
