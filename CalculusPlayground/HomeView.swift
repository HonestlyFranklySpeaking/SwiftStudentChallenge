//
//  HomeView.swift
//  CalculusPlayground
//
//  Created by Timothy Qin on 8/1/26.
//
import SwiftUI
let views: [any IdentifiableView] = [TaylorSeriesPlayground(), TangentLinePlayground(), DerivativePlayground()]

struct HomeView: View {
    var body: some View {
        NavigationStack {
            Form {
                ForEach(views) {view in
                    NavigationLink("Taylor Series 2") {
                        AnyView(view)
                    }
                    
                    
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
    
