//
//  View.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

import SwiftUI
struct LoginView<T: LoginViewModel>: View {
    @ObservedObject var presenter: T
    @State var value: String = ""
    init(model: T) {
        self.presenter = model
    }
    
    var body: some View {
        Text("Hello, World!")
        Text(value)
        Button("Login", action: {
            presenter.onTapLogin("Saldivar", "Saldivar")
            Task {
                value = await presenter.model.getValue()
            }
        })
    }
    
}
