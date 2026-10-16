//
//  GitHubUserProfile.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Entity
//  Representa el perfil de usuario de GitHub (@fsaldivar-dev).
//  Totalmente agnóstico de frameworks de UI o inyección de dependencias.
//

import Foundation

public struct GitHubUserProfile: Codable, Sendable, Equatable {
    public let login: String
    public let name: String
    public let bio: String
    public let location: String
    public let avatarURL: String
    public let htmlURL: String
    public let publicRepos: Int
    public let followers: Int
    public let following: Int

    public init(
        login: String,
        name: String,
        bio: String,
        location: String,
        avatarURL: String,
        htmlURL: String,
        publicRepos: Int,
        followers: Int,
        following: Int
    ) {
        self.login = login
        self.name = name
        self.bio = bio
        self.location = location
        self.avatarURL = avatarURL
        self.htmlURL = htmlURL
        self.publicRepos = publicRepos
        self.followers = followers
        self.following = following
    }

    public static let fsaldivarDefault = GitHubUserProfile(
        login: "fsaldivar-dev",
        name: "Saldivar",
        bio: "Desarrollador mobile · Creador de DaggerSwift, AutoPilot & Codaru",
        location: "MX",
        avatarURL: "https://avatars.githubusercontent.com/u/16517868?v=4",
        htmlURL: "https://github.com/fsaldivar-dev",
        publicRepos: 26,
        followers: 10,
        following: 8
    )
}
