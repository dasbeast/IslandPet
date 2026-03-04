//
//  IslandPetLoadingView.swift
//  IslandPet
//
//  Created by Bailey Kiehl on 6/18/25.
//


import SwiftUI

struct IslandPetLoadingView: View {
    var body: some View {
        ZStack {
            // Optional: match your app’s background color
            //Color(.systemBackground)
               // .ignoresSafeArea()

            VStack(spacing: 20) {
                // If you have a logo asset, replace "AppLogo" with its name
                Image("winnie")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)

                ProgressView("Loading your pet…")
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2, anchor: .center)
            }
        }
    }
}

#Preview {
    IslandPetLoadingView()
}
