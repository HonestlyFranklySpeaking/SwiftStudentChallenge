//
//  IntegralPlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI
import Charts

struct IntegralPlayground: View {
    @State var done: Bool = false
    @State var bigDone: Bool = false
    @State var c1: Double = 0
    @State var c2: Double = 0
    @State var function: Function = Function.sine
    @State var inputPoints: [GraphPoint] = []
    
    @State var baseIntegralPoints: [GraphPoint] = []
    @State var baseSecondIntegralPoints: [GraphPoint] = []
    
    @State var integralPoints: [GraphPoint] = []
    
    
    
    @State var secondIntegralPoints: [GraphPoint] = []
    
    @State var xDomain: ClosedRange<Double> = -30...30
    
    
    @State private var debug: String = ""
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if bigDone { MathGraph(serieses: [
                    Series(points: inputPoints, label: "Function"),
                    Series(points: integralPoints, label: "Integral"),
                    Series(points: secondIntegralPoints, label: "Second Integral")
                ]) } else {
                    ProgressView()
                }
                Spacer()
                Text("\(Helpers.shared.makeScriptedString("C", script: "0", exponent: false)): \(String(format: "%.1f", c1))")
                Slider(value: $c1, in: -10...10, step: 0.2, label: { Text("C0") })
                Text("\(Helpers.shared.makeScriptedString("C", script: "1", exponent: false)): \(String(format: "%.1f", c2))")
                Slider(value: $c2, in: -10...10, step: 0.2, label: { Text("C1") })
                
                Text(debug)
            }
            .navigationTitle("Integrals")
            .padding()
            .task {
                bigDone = false
                done = false
                await Task.detached(name: "Startup Update", priority: .high) {
                    let result = await update(function: function, points: (inputPoints, integralPoints, secondIntegralPoints), basePoints: (baseIntegralPoints, baseSecondIntegralPoints))
                    
                    await setPoint(result)
                    
                }.value
                done = true
                bigDone = true
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
                
            }
        }
        .onChange(of: function) { _, _ in
            Task {
                done = false
                bigDone = false
                await Task.detached(name: "Change after func modification", priority: .high) {
                    let result = await update(function: function, points: (inputPoints, integralPoints, secondIntegralPoints), basePoints: (baseIntegralPoints, baseSecondIntegralPoints))
                    
                    await setPoint(result)
                    
                }.value
                done = true
                bigDone = true
            }
        }
        .onChange(of: c1) { j, k in
            Task {
                
                
                //Starts at 1 because you don't have to regenerate og points or integral
                done = false
                await Task.detached(name: "Change after c1(0) modification", priority: .high) {
                    let result = await update(function: function, startAt: .one(c0: c1, c1: c2), points: (inputPoints, integralPoints, secondIntegralPoints), basePoints: (baseIntegralPoints, baseSecondIntegralPoints))
                    
                    await setPoint(result)
                    
                }.value
                done = true
            }
        }
        .onChange(of: c2) { _, _ in
            Task {
                //Starts at step 2 because only integral 2 is affected
                done = false
                await Task.detached(name: "Change after c1(2) modification", priority: .high) {
                    let result = await update(function: function, startAt: .two(c0: c1, c1: c2), points: (inputPoints, integralPoints, secondIntegralPoints), basePoints: (baseIntegralPoints, baseSecondIntegralPoints))
                    
                    await setPoint(result)
                    
                    
                }.value
                done = true
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
        case one(c0: Double, c1: Double)
        case two(c0: Double, c1: Double)
    }
    
    nonisolated func update(function: Function, startAt: updateStartAt = .zero, points: ([GraphPoint], [GraphPoint], [GraphPoint]), basePoints: ([GraphPoint], [GraphPoint])) async -> (([GraphPoint], [GraphPoint]?, [GraphPoint], [GraphPoint]?, [GraphPoint]?)) {
        
        var inputPoints = points.0
        var integralPoints = points.1
        var secondIntegralPoints = points.2
        
        var baseIntegralPoints = basePoints.0
        var baseSecondIntegralPoints = basePoints.1
        
        var resultIntegralPoints: [GraphPoint]? = nil
        var resultBaseIntegralPoints: [GraphPoint]? = nil
        var resultBaseSecondIntegralPoints: [GraphPoint]? = nil
        
        if case .zero = startAt {
            
            integralPoints = []
            secondIntegralPoints = []
            
            inputPoints = await generateData(function: function)
            baseIntegralPoints = await generateIntegral(for: inputPoints)
            for point in baseIntegralPoints {
                await integralPoints.append(GraphPoint(xh: point.xh, yv: point.yv+c1, asynch: ()))
            }
            
            baseSecondIntegralPoints = await generateIntegral(for: baseIntegralPoints)
            for point in baseSecondIntegralPoints {
                await secondIntegralPoints.append(GraphPoint(xh: point.xh, yv: point.yv+c2, asynch: ()))
            }
            
            resultBaseIntegralPoints = baseIntegralPoints
            resultBaseSecondIntegralPoints = baseSecondIntegralPoints
            resultIntegralPoints = integralPoints
            
        }
        
        //For .one and .two, it is intentional to use [i] rather than modifying the property as it makes swift dupe the array. Please do not modify
        
        if case .one(let C0, let C1) = startAt {
            
            for (i, point) in baseIntegralPoints.enumerated() {
                await integralPoints[i] = GraphPoint(xh: point.xh, yv: point.yv + C0, asynch: ())
                
                let secondPoint = baseSecondIntegralPoints[i]
                
                await secondIntegralPoints[i] = GraphPoint(xh: secondPoint.xh, yv: secondPoint.yv + C0 * secondPoint.xh + C1, asynch: ())
            }
            
            resultIntegralPoints = integralPoints
        }
        if case .two(let C0, let C1) = startAt {
            
            for (i, point) in baseSecondIntegralPoints.enumerated() {
                await secondIntegralPoints[i] = GraphPoint(xh: point.xh, yv: point.yv + C0 * point.xh + C1, asynch: ())
            }
            
        }
        
        
        return ((inputPoints, resultIntegralPoints, secondIntegralPoints, resultBaseIntegralPoints, resultBaseSecondIntegralPoints))
    }
    
    ///In order: inputPoints, integralPoints, 2ndIntegralPoints, baseIntegralPoints, secondBaseIntegralPoints
    func setPoint(_ points: ([GraphPoint]?, [GraphPoint]?, [GraphPoint]?, [GraphPoint]?, [GraphPoint]?)) async {
        if let newInputPoints = points.0 {
            inputPoints = newInputPoints
        }
        if let newIntegralPoints = points.1 {
            integralPoints = newIntegralPoints
        }
        if let newSecondIntegralPoints = points.2 {
            secondIntegralPoints = newSecondIntegralPoints
        }
        if let newBaseIntegralPoints = points.3 {
            baseIntegralPoints = newBaseIntegralPoints
        }
        if let newBaseSecondIntegralPoints = points.4 {
            baseSecondIntegralPoints = newBaseSecondIntegralPoints
        }
    }
}



#Preview {
    HomeView()
}
