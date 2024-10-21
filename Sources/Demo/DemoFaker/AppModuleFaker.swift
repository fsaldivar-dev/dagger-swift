//
//  AppModuleFaker.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

import DaggerSwift
import SampleProyect

enum AppModuleImpl: AppModule {
    @Provider( DataRepositoryFakerImpl() )
    static var dataRepository: any DataRepository
    
    @Provider( AppClientFakerImpl() )
    static var appClient: any ApiClient
    
    @Singleton(AnalyticsFakerImpl())
    static var analytics: any Analytics
    
    @Provider( AppRepositoryFakerImpl() )
    static var appRepository: any AppRepository
}

final class DataRepositoryFakerImpl: DataRepository {
    func fetchData() -> [String] {
        ["Faker Data"]
    }
}


final actor AppClientFakerImpl: ApiClient {
    func execute(url: String) async throws -> String {
        "Response faker"
    }
}

final actor AnalyticsFakerImpl: Analytics {
    func track(event: String) {
        print("Faker")
    }
}

final class AppRepositoryFakerImpl: AppRepository {
    func fetchApps() async throws -> [String] {
        ["Faker"]
    }
}
