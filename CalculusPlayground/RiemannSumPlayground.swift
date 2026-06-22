//
//  DerivativePlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI; import SwiftData
import Charts

struct RiemannSumPlayground: View {
    @State var visualInputPoints: [GraphPoint] = []
    @State var increment: Double = 1
    
    let visualIncrement: Double = 0.05
    
    @State var showFunctionOptions: Bool = false
    
    @State var function: Function = Function.sine
    @State var inputPoints: [GraphPoint] = []
    @State var xDomain: ClosedRange<Double> = -30...30
    @State var rectanglePoints = [] as [GraphPoint]
    @State var range: ClosedRange<Double> = 0...5
    @State var integral: Double = 0
    @State private var debug: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MathGraph(serieses: [
                    Series(points: visualInputPoints, label: "Function"),
                    Series(points: rectanglePoints, label: "Riemann Sum", plottype: .area)
                ])
                Spacer()
                
                Text(String(format: "%.2f", increment))
                
                Slider(value: $increment, in: 0.005...1 as ClosedRange<Double>, step: 0.005) {
                    Text("Increment size")
                }
                
                
                Capsule()
                    .fill(Color.gray)
                    .frame(height: 6)
                    .rangeSlider(range: $range, in: -30...30, step: 0.1)
                    .padding()
                
                
                Text("\(String(format: "%.1f", range.lowerBound)) - \(String(format: "%.1f", range.upperBound))")
                Text(debug)
                integralEquation
            }
            .navigationTitle("Riemann Sums")
            .padding()
            .task {
                await update()
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
        .onChange(of: range) {
            Task {
                await update()
            }
        }
        .onChange(of: function) {
            Task {
                await update()
            }
        }
        .onChange(of: increment) {
            Task {
                await update()
            }
        }
        
    }
    ///To be done after a change, generates new data and takes definite integral
    func update() async {
        inputPoints = await generateData(step: increment)
        visualInputPoints = await generateData(step: visualIncrement)
        do {
            (integral, rectanglePoints) = try await riemannSum(for: inputPoints, range: ReversibleRange(range))
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func generateData(step: Double) async -> [GraphPoint] {
        let f = function
        let range: ClosedRange<Double> = -30...30
        let points: [GraphPoint] = await Task.detached(priority: .utility) {
            await makeInputs(for: f, range: range, step: step)
        }.value
        print("\nGenerated \(points.count) points for function \(f.id.uuidString.prefix(6)) \n")
        return points
        
    }
    
    var integralEquation: some View {
        HStack {
            HStack(spacing: 0.5) {
                Text("∫")
                    .font(.largeTitle)
                VStack {
                    Text(String(format: "%.2f", range.upperBound))
                        .font(.caption)
                        .padding(0.7)
                    Text(String(format: "%.2f", range.lowerBound))
                        .font(.caption)
                        .padding(0.5)
                }
            }
            
            Text(function.mathText ?? "f(x)")
            
            Text("dx ≈ \((String(format: "%.2f", bucket(integral, step: 0.01))))")
            
        }
    }
}


#Preview {
    RiemannSumPlayground()
}


