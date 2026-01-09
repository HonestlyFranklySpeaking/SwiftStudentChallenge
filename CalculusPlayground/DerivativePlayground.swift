//
//  DerivativePlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI
import Charts

struct DerivativePlayground: View {
    
    @State var function: Function = Function.sine
    @State var inputPoints: [GraphPoint] = []
    
    @State var derivativePoints: [GraphPoint] = []
    
    @State var xDomain: ClosedRange<Double> = -30...30
    
    
    @State private var debug: String = ""
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MathGraph(xDomain: $xDomain, inputPoints: $inputPoints, derivedPoints: $derivativePoints)
                
                Spacer()
                
                
                Text(debug)
            }
            .navigationTitle("Derivatives")
            .padding()
            .task {
                await generateData()
                
                do {
                    derivativePoints = try await mapDerivative(for: inputPoints)
                } catch {
                    print(error.localizedDescription)
                }
            }
            .toolbar {
                Menu {
                    Picker(selection: $function) {
                        Text("Sine").tag(Function.sine)
                        Text("Exponential").tag(Function.exp)
                        Text("Square").tag(Function.square)
                        Text("Natural Log").tag(Function.naturalLog)
                        Text("Polynomial").tag(Function.humpy)
                        Text("Inverse").tag(Function.inverse)
                    } label: {
                        Text("Functions")
                    }
                } label: {
                    Image(systemName: "graph.2d")
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.purple))
                }
                .onChange(of: function) { _, _ in
                    Task {
                        await generateData()
                        
                        do {
                            derivativePoints = try await mapDerivative(for: inputPoints)
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                    
                }
            }
        }
    }
    
    
    
    func generateData() async {
        let f = function
        let range: ClosedRange<Double> = -30.0...30.0
        let step: Double = Helpers.shared.increment
        let points: [GraphPoint] = await Task.detached(priority: .utility) {
            await makeInputs(for: f, range: range, step: step)
        }.value
        inputPoints = points
        print("\n Generated \(points.count) points for function \(f.id.uuidString.prefix(6)) \n")
    }
    
}



#Preview {
    DerivativePlayground()
}
