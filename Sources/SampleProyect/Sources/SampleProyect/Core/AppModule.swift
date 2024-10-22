//
//  AppModule.swift
//  SampleProyect
//
//  Created by Saldivar on 21/10/24.
//

import DaggerSwift
import Foundation
import UIKit
import SwiftUI

public protocol AppModule: Modulable {
    static var appClient: ApiClient { get }
    static var analytics: Analytics { get }
    static var appRepository: AppRepository { get }
    static var dataRepository: DataRepository { get }
}

public enum SampleProyectDispatcherRoutes {
    case login
    case error
}

public actor SampleProyectDispatcher {
    static var module: AppModule.Type!
    
    @MainActor
    public static func build<T: AppModule>(module: T.Type, route: SampleProyectDispatcherRoutes) -> any View {
        Self.module = module
        switch route {
        case .login:
            LoginComponentImpl<T>.loginView()
        case .error:
            fatalError("")
        }
        return LoginComponentImpl<T>.loginView()
    }
}
