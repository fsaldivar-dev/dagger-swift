//
//  AppModule.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//
import DaggerSwift
import SampleProyect

enum AppModuleImpl: AppModule {
    @Provider( DataRepositoryImpl() )
    static var dataRepository: any DataRepository
    
    @Provider( ApiClienRealImpl() )
    static var appClient: any ApiClient
    
    @Singleton(AnalyticsImpl())
    static var analytics: any Analytics
    
    @Provider( AppRepositoryImpl(api: Self.appClient) )
    static var appRepository: any AppRepository
}
