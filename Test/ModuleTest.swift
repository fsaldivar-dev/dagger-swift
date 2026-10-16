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
    static var apiService: ApiService { get }
    static func provideUserRepository(apiService: ApiService) -> UserRepository
    static var analisisRepository: AnalisiRepository { get }
}


protocol AppComponent: Component {}



enum AppModuleImpl: AppModule {
    @Provider(wrappedValue: ApiService())
    static var apiService: ApiService

    @Singleton(wrappedValue: AnalisiRepository(apiService: apiService))
    static var analisisRepository: AnalisiRepository
    
    static func provideUserRepository(apiService: ApiService) -> UserRepository {
        .init(apiService: apiService)
    }
}


struct LoginComponent<Module: AppModule>: AppComponent {
    static func injectLoginSubModule() -> LoginSubModule {
        .init(analisiRepository: Module.analisisRepository,
              userRepository: Module.provideUserRepository(apiService: Module.apiService))
    }
}

struct LoginSubModule {
    let analisiRepository: AnalisiRepository
    let userRepository: UserRepository
    
    init(analisiRepository: AnalisiRepository, userRepository: UserRepository) {
        self.analisiRepository = analisiRepository
        self.userRepository = userRepository
    }
}

import Testing

@Suite("Dagger 1 - Module & Component Tests")
@MainActor
struct DaggerV1Tests {
    @Test("Singleton devuelve siempre la misma instancia y Provider devuelve instancias nuevas en cada lectura")
    func testSingletonAndProviderInV1() {
        let firstSubModule = LoginComponent<AppModuleImpl>.injectLoginSubModule()
        let secondSubModule = LoginComponent<AppModuleImpl>.injectLoginSubModule()

        // @Singleton conserva la misma referencia en memoria
        #expect(firstSubModule.analisiRepository === secondSubModule.analisiRepository)

        // @Provider crea una nueva instancia en cada lectura de propiedad
        #expect(AppModuleImpl.apiService !== AppModuleImpl.apiService)
        #expect(firstSubModule.userRepository !== secondSubModule.userRepository)
    }
}
