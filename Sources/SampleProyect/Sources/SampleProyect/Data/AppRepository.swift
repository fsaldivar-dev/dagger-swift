//
//  AppRepository.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

public protocol AppRepository {
    func fetchApps() async throws -> [String]
}

public final class AppRepositoryImpl: AppRepository {
    let api: ApiClient
    
    public init(api: ApiClient) {
        self.api = api
    }
    
    public func fetchApps() async throws -> [String] {
        [try await api.execute(url: "dummy")]
    }
}
