//
//  DerivativePlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI; import SwiftData
import Charts

struct DerivativePlayground: View {
    
    @State var function: Function = Function.sine
    @State var inputPoints: [GraphPoint] = []
    
    @State var derivativePoints: [GraphPoint] = []
    @State var secondDerivativePoints: [GraphPoint] = []
    @State var xDomain: ClosedRange<Double> = -30...30
    
    @State var showFunctionOptions: Bool = false
    
    
    @State private var debug: String = ""
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MathGraph(serieses: [
                    Series(points: inputPoints, label: "Function"),
                    Series(points: derivativePoints, label: "Derivative"),
                    Series(points: secondDerivativePoints, label: "Second Derivative")
                ])
                
                Spacer()

                Text(debug)
            }
            .navigationTitle("Derivatives")
            .padding()
            .task {
                await generateData()
                
                do {
                    derivativePoints = try await mapDerivative(for: inputPoints)
                    secondDerivativePoints = try await mapDerivative(for: derivativePoints)
                } catch {
                    print(error.localizedDescription)
                }
            }
            .onChange(of: function) { _, _ in
                Task {
                    await generateData()
                    
                    do {
                        derivativePoints = try await mapDerivative(for: inputPoints)
                        secondDerivativePoints = try await mapDerivative(for: derivativePoints)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showFunctionOptions.toggle()
                    } label: {
                        Image(systemName: "graph.2d")
                    }
                    .tint(.purple)
                    .buttonStyle(.glassProminent)
                    .popover(isPresented: $showFunctionOptions) {
                        FunctionSelector(function: $function, showFunctionOptions: $showFunctionOptions)
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
