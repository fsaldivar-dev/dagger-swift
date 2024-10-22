//
//  DemoApp.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

import SwiftUI
import SampleProyect

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            AnyView( SampleProyectDispatcher.build(module: AppModuleImpl.self, route: .login))
        }
    }
}
