//
//  View.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

import SwiftUI
struct LoginView<T: LoginViewModel>: View {
    @ObservedObject var model: T
    
    init(model: T) {
        self.model = model
    }
    
    var body: some View {
        Text("Hello, World!")
        
        Button("Login", action: {
            model.username = "Saldivar"
            model.password = "Saldivar"
            try?  model.onTapLogin()
        })
    }
    
}
