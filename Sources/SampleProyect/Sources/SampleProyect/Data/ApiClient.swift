//
//  ApiClient.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

public protocol ApiClient: Actor {
    func execute(url: String) async throws -> String
}

public actor ApiClienRealImpl: ApiClient {
    public init() {}
    public func execute(url: String ) async  throws -> String {
        return "Real implementation"
    }
}
