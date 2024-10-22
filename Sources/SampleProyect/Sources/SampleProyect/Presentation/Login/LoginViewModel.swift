//
//  LoginViewModel.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

import SwiftUI
import Combine

// Protocolo del ViewModel
protocol LoginViewModel: ObservableObject {
    var model: ActorLoginViewModel { get set }
    func onTapLogin(_ username: String, _ password: String)
}

// Actor que maneja el estado concurrente
actor ActorLoginViewModel {
    private var username: String = ""
    private var password: String = ""
    private var value: String = ""
    private var loginUseCase: LoginUseCase
    
    init(loginUseCase: LoginUseCase) {
        self.loginUseCase = loginUseCase
    }
    
    // PassthroughSubject para emitir cambios en la propiedad `value`
    let valueSubject = PassthroughSubject<String, Never>()
    
    // Publicador que expone los cambios de `value` para que otros se suscriban
    var valuePublisher: AnyPublisher<String, Never> {
        valueSubject.eraseToAnyPublisher()
    }
    
    // Métodos seguros para actualizar el estado
    func updateValue(value: String) {
        self.value = value
        // Emitir el nuevo valor de forma reactiva
        valueSubject.send(value)
    }
    
    func setUsername(_ username: String) {
        self.username = username
    }
    
    func setPassword(_ password: String) {
        self.password = password
    }
    
    // Métodos para obtener el estado actual
    func getUsername() -> String {
        return username
    }
    
    func getPassword() -> String {
        return password
    }
    
    func getValue() -> String {
        value
    }
    
    func fetchLogin() async throws {
        self.value = try await loginUseCase.login(with: username, password: password)
    }
}

// Implementación del ViewModel

final class LoginViewModelImpl: LoginViewModel {
    @Published var model: ActorLoginViewModel
    private var task: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    @Published var currentValue: String = ""

    init(loginUseCase: LoginUseCase) {
        model = ActorLoginViewModel(loginUseCase: loginUseCase)
    }
  
    // Manejo del evento onTapLogin
    func onTapLogin(_ username: String, _ password: String) {
        task?.cancel()
        task = Task { [model] in
            do {
                // Actualizar el username y password en el actor
                await model.setUsername(username)
                await model.setPassword(password)
                try await model.fetchLogin()
            } catch {
                print(error)
            }
        }
    }
    
    // Cancelación de tareas y recursos
    deinit {
        task?.cancel()
        task = nil
    }
}
