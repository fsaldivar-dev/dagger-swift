//
//  LoginComponent.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

import DaggerSwift
import SwiftUI

protocol LoginComponent: Component {
    
    static func loginView() async -> any View
}

enum LoginComponentImpl<Module: AppModule>: LoginComponent {
    
    @MainActor public static func loginView() -> any View {
        let loginUseCase = LoginUseCaseImpl(apiClient: module.appClient)
        let model = LoginViewModelImpl(loginUseCase: loginUseCase)
        let view = LoginView<LoginViewModelImpl>.init(model: model)
        return view
    }
}
