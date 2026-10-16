//
//  ContentView.swift
//  DemoFaker
//
//  Clean Architecture + MVVM + DaggerSwift v2 Sandbox Showcase
//

import SwiftUI
import DaggerSwift
import SampleProyect

struct ContentView: View {
    var body: some View {
        ShowcaseRootView(environment: FakerGitHubModule.self)
    }
}

#Preview {
    ContentView()
}
