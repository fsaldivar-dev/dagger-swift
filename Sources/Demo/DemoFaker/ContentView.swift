//
//  ContentView.swift
//  DemoFaker
//
//  Clean Architecture + MVVM + DaggerSwift v2 Showcase
//

import SwiftUI
import DaggerSwift
import SampleProyect

struct ContentView: View {
    var body: some View {
        ShowcaseRootView(initialTab: .fintechAB)
    }
}

#Preview {
    ContentView()
}
