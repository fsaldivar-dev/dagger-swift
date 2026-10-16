//
//  DemoFakerApp.swift
//  DemoFaker
//
//  Created by Saldivar on 21/10/24.
//  Updated to DaggerSwift v2 Declarative Showcase (Faker Offline Deterministic Sandbox).
//

import SwiftUI
import DaggerSwift
import SampleProyect

@main
struct DemoFakerApp: App {
    var body: some Scene {
        WindowGroup {
            DaggerShowcaseRootView(environment: FakerGitHubModule.self)
        }
    }
}
