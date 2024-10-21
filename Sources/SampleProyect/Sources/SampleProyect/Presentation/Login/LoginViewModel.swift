//
//  LoginViewModel.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

import SwiftUI

protocol LoginViewModel: ObservableObject {
    var username: String { get set }
    var password: String { get set }
    func onTapLogin() throws
}

@MainActor
final class LoginViewModelImpl: @preconcurrency LoginViewModel {
    @Published var username: String = ""
    @Published var password: String = ""
    private var loginUseCase: LoginUseCase
    
    init(loginUseCase: LoginUseCase) {
        self.loginUseCase = loginUseCase
    }
    
    
    func onTapLogin()  throws {
        Task {
            let result =  try await loginUseCase.login(with: username, password: password)
            print(result)
        }
    }
    
}
