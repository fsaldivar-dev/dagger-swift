//
//  CommonError.swift
//  SampleProyect
//
//  Created by Saldivar on 22/10/24.
//

import SwiftUI

struct ErrorView: View {
    var errorMessage: String
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.red)
                .padding(.top, 40)

            Text("Oops, something went wrong!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                onRetry()
            }) {
                Text("Try Again")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
    }
}

struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorView(errorMessage: "Unable to fetch data. Please check your connection.") {
            // Retry action
        }
    }
}
