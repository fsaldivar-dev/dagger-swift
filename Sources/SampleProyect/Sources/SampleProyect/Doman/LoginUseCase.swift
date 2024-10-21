//
//  LoginUseCase.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

public protocol LoginUseCase: Actor {
    func login(with user: String, password: String) async throws -> String
}

actor LoginUseCaseImpl: LoginUseCase {
    private let apiClient: ApiClient
    
    init(apiClient: ApiClient) {
        self.apiClient = apiClient
    }
    
    
    func login(with user: String, password: String) async throws-> String {
        try await self.apiClient.execute(url: "login")
    }
}
