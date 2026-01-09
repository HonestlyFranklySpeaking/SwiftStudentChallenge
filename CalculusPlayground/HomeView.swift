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
                NavigationLink(destination: TaylorSeriesPlayground()) {
                    Text("Taylor Series")
                }
                NavigationLink(destination: TangentLinePlayground()) {
                    Text("Tangent Line")
                }
                NavigationLink(destination: DerivativePlayground()) {
                    Text("Derivative")
                }
                
            }
            .navigationTitle("Function Playground")
        }
    }
}

#Preview {
    HomeView()
}



protocol IdentifiableView: Identifiable, View {
    var id: UUID { get set }
    var body: any View { get set }
}

