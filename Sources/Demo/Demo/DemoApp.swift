//
//  DemoApp.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//  Updated to DaggerSwift v2 Declarative Showcase (Live GitHub REST API @fsaldivar-dev).
//

import SwiftUI
import DaggerSwift
import SampleProyect

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            DaggerShowcaseRootView(environment: LiveGitHubModule.self)
        }
    }
}
