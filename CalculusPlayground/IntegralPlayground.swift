//
//  DerivativePlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI
import Charts

struct IntegralPlayground: View {
    @State var done: Bool = false
    @State var c1: Double = 0
    @State var c2: Double = 0
    @State var function: Function = Function.sine
    @State var inputPoints: [GraphPoint] = []
    
    @State var integralPoints: [GraphPoint] = []
    @State var secondIntegralPoints: [GraphPoint] = []
    @State var xDomain: ClosedRange<Double> = -30...30
    
    
    @State private var debug: String = ""
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MathGraph(serieses: [
                    Series(points: inputPoints, label: "Function"),
                    Series(points: integralPoints, label: "Integral"),
                    Series(points: secondIntegralPoints, label: "Second Integral")
                ])
                Spacer()
                Text("\(Helpers.shared.makeScriptedString("C", script: "0", exponent: false)): \(String(format: "%.1f", c1))")
                Slider(value: $c1, in: -10...10, step: 0.1, label: { Text("C0") })
                Text("\(Helpers.shared.makeScriptedString("C", script: "1", exponent: false)): \(String(format: "%.1f", c2))")
                Slider(value: $c2, in: -10...10, step: 0.1, label: { Text("C1") })
                
                Text(debug)
            }
            .navigationTitle("Integrals")
            .padding()
            .task {
                done = false
                await Task.detached(priority: .medium) {
                    await (inputPoints, integralPoints, secondIntegralPoints) = await update(function: function, points: (inputPoints, integralPoints, secondIntegralPoints))
                }.value
                done = true
            }
            .toolbar {
                Image(systemName: done ? "checkmark.circle.fill" : "xmark.circle.fill")
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
                        done = false
                        await Task.detached(priority: .medium) {
                            await (inputPoints, integralPoints, secondIntegralPoints) = await update(function: function, points: (inputPoints, integralPoints, secondIntegralPoints))
                        }.value
                        done = true
                    }
                }
                .onChange(of: c1) {j, k in
                    Task {
                        //Starts at 1 because you don't have to regenerate og points or integral
                        done = false
                        await Task.detached(priority: .medium) {
                            await (inputPoints, integralPoints, secondIntegralPoints) = await update(function: function, startAt: .one(start: j, end: k), points: (inputPoints, integralPoints, secondIntegralPoints))
                        }.value
                        done = true
                    }
                }
                .onChange(of: c2) {j, k in
                    Task {
                        //Starts at step 2 because only integral 2 is affected
                        done = false
                        await Task.detached(priority: .medium) {
                            await (inputPoints, integralPoints, secondIntegralPoints) = await update(function: function, startAt: .two(start: j, end: k), points: (inputPoints, integralPoints, secondIntegralPoints))
                        }.value
                        done = true
                    }
                }
            }
        }
    }
    
    nonisolated func generateData(function f: Function) async -> [GraphPoint] {
        let range: ClosedRange<Double> = -30.0...30.0
        let step: Double = await Helpers.shared.increment
        let points: [GraphPoint] = await Task.detached(priority: .utility) {
            await makeInputs(for: f, range: range, step: step)
        }.value
        print("\n Generated \(points.count) points for function \(f.id.uuidString.prefix(6)) \n")
        return points
    }
    
    enum updateStartAt: Equatable {
        case zero
        case one(start: Double, end: Double)
        case two(start: Double, end: Double)
    }
    
    nonisolated func update(function: Function, startAt: updateStartAt = .zero, points: ([GraphPoint], [GraphPoint], [GraphPoint])) async -> ([GraphPoint], [GraphPoint], [GraphPoint]) {
        var (inputPoints, integralPoints, secondIntegralPoints) = points
        if case .zero = startAt {
            inputPoints = await generateData(function: function)
            integralPoints = await generateIntegral(for: inputPoints)
            for (i, point) in integralPoints.enumerated() { await integralPoints[i].setY(point.yv+c1)
            }
            secondIntegralPoints = await generateIntegral(for: integralPoints)
            for (i, point) in secondIntegralPoints.enumerated() { await secondIntegralPoints[i].setY(point.yv+c2)
            }
        }
        if case let .one(start: j, end: k) = startAt {
            for (i, _) in integralPoints.enumerated() {
                await integralPoints[i].setY(integralPoints[i].yv + k - j)
            }
            for (i, point) in secondIntegralPoints.enumerated() {
                await secondIntegralPoints[i].setY(secondIntegralPoints[i].yv + (k - j) * point.xh)
            }
        }
        if case let .two(start: j, end: k) = startAt {
            for (i, _) in secondIntegralPoints.enumerated() {
                await secondIntegralPoints[i].setY(secondIntegralPoints[i].yv + k - j)
            }
        }
        return (inputPoints, integralPoints, secondIntegralPoints)
    }

}



#Preview {
    HomeView()
}
