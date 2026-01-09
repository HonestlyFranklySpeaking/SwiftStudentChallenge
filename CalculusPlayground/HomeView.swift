//
//  HomeView.swift
//  CalculusPlayground
//
//  Created by Timothy Qin on 8/1/26.
//
import SwiftUI


struct HomeView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    NavigationLink(destination: TangentLinePlayground()) {
                        Text("Tangent Lines")
                    }
                    NavigationLink(destination: DerivativePlayground()) {
                        Text("Derivative")
                    }
                }
                
                
                Section("Applied") {
                    NavigationLink(destination: TaylorSeriesPlayground()) {
                        Text("Taylor Series")
                    }
                }
                
                Section("Abstract") {
                    
                }
            }
            .navigationTitle("Math Playgrounds")
        }
    }
}

#Preview {
    HomeView()
}




