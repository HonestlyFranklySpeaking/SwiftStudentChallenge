//
//  HomeView.swift
//  CalculusPlayground
//
//  Created by Timothy Qin on 8/1/26.
//
import SwiftUI
import SwiftData


struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Helpers.shared.backgroundGradient
                    .ignoresSafeArea()
                
                Form {
                    Section("Basics") {
                        Group {
                            NavigationLink(destination: TangentLinePlayground()) {
                                Text("Tangent Lines")
                            }
                            NavigationLink(destination: DerivativePlayground()) {
                                Text("Derivatives")
                            }
                            NavigationLink(destination: RiemannSumPlayground()) {
                                Text("Riemann Sums")
                            }
                            NavigationLink(destination: IntegralPlayground()) {
                                Text("Integrals")
                            }
                        }
                        .listRowBackground(Color.clear.background(.regularMaterial))
                    }
                    
                    
                    Section("Applied") {
                        Group {
                            NavigationLink(destination: TaylorSeriesPlayground()) {
                                Text("Taylor Series")
                            }
                            NavigationLink(destination: FunctionInputField()) {
                                Text("AutoDiff")
                            }
                        }
                        .listRowBackground(Color.clear.background(.regularMaterial))
                    }
                    
                    Section("Abstract") {
                        
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Math Playgrounds")
            }
        }
        
    }
}
#Preview {
    HomeView()
}




