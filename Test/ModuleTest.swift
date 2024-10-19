//
//  ModuleTest.swift
//  DaggerSwift
//
//  Created by Saldivar on 18/10/24.
//

import DaggerSwift

final class ApiService {
    func fetchData() {
        print("Fetching data...")
    }
}

final class UserRepository {
    private var apiService: ApiService
    init (apiService: ApiService) {
        self.apiService = apiService
    }
}

final class AnalisiRepository {
    private var apiService: ApiService
    init (apiService: ApiService) {
        self.apiService = apiService
    }
}



protocol AppModule: Modulable {
    static func provideApiService() -> ApiService
    static func provideUserRepository(apiService: ApiService) -> UserRepository
    static var analisisRepository: AnalisiRepository { get set }
}


protocol AppComponent: Component {}



enum AppModuleImpl: AppModule {
    @Singleton(wrappedValue: .init(apiService: provideApiService()))
    static var analisisRepository: AnalisiRepository
    
    static func provideApiService() -> ApiService {
        .init()
    }
    
    static func provideUserRepository(apiService: ApiService) -> UserRepository {
        .init(apiService: apiService)
    }
}


struct LoginComponent<Module: AppModule>: AppComponent {
    static func injectLoginSubModule() -> LoginSubModule {
        .init(analisiRepository: Module.analisisRepository,
              userRepository: Module.provideUserRepository(apiService: Module.provideApiService()))
    }
}

struct LoginSubModule {
    private var analisiRepository: AnalisiRepository
    private var userRepository: UserRepository
    
    init(analisiRepository: AnalisiRepository, userRepository: UserRepository) {
        self.analisiRepository = analisiRepository
        self.userRepository = userRepository
    }
}
