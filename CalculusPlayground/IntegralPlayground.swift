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
    
    @State var baseIntegralPoints: [GraphPoint] = []
    @State var baseSecondIntegralPoints: [GraphPoint] = []
    
    @State var integralPoints: [GraphPoint] = []
    
    
    
    @State var secondIntegralPoints: [GraphPoint] = []

    @State var xDomain: ClosedRange<Double> = -30...30
    
    
    @State private var debug: String = ""
    
    
    var body: some View {
        NavigationStack {
            internalVStack
            .navigationTitle("Integrals")
            .padding()
            .task {
                
                done = false
                await Task.detached(priority: .medium) {
                    let result = await update(function: function, points: (inputPoints, integralPoints, secondIntegralPoints), basePoints: (baseIntegralPoints, baseSecondIntegralPoints))
                
                    await (inputPoints, integralPoints, secondIntegralPoints) = result.0
                    if let baseIntPoints = result.1.0 {
                        await setBaseIntegral(baseIntPoints)
                    }
                    if let secondBaseIntPoints = result.1.1 {
                        await setSecondBaseIntegral(secondBaseIntPoints)
                    }
                    
                }.value
                done = true
            }
            .toolbar {
                Image(systemName: done ? "checkmark.circle.fill" : "xmark.circle.fill")
                menu
            }
        }
        .onChange(of: function) { _, _ in
            Task {
                done = false
                await Task.detached(priority: .medium) {
                    let result = await update(function: function, points: (inputPoints, integralPoints, secondIntegralPoints), basePoints: (baseIntegralPoints, baseSecondIntegralPoints))
                    await (inputPoints, integralPoints, secondIntegralPoints) = result.0
                    if let baseIntPoints = result.1.0 {
                        await setBaseIntegral(baseIntPoints)
                    }
                    if let secondBaseIntPoints = result.1.1 {
                        await setSecondBaseIntegral(secondBaseIntPoints)
                    }
                }.value
                done = true
            }
        }
        .onChange(of: c1) { _, _ in
            Task {
                //Starts at 1 because you don't have to regenerate og points or integral
                done = false
                await Task.detached(priority: .medium) {
                    let result = await update(function: function, startAt: .one, points: (inputPoints, integralPoints, secondIntegralPoints), basePoints: (baseIntegralPoints, baseSecondIntegralPoints))
                    
                
                    await (inputPoints, integralPoints, secondIntegralPoints) = result.0
                    
                    if let baseIntPoints = result.1.0 {
                        await setBaseIntegral(baseIntPoints)
                    }
                    if let secondBaseIntPoints = result.1.1 {
                        await setSecondBaseIntegral(secondBaseIntPoints)
                    }
                    

                }.value
                done = true
            }
        }
        .onChange(of: c2) { _, _ in
            Task {
                //Starts at step 2 because only integral 2 is affected
                done = false
                await Task.detached(priority: .medium) {
                    let result = await update(function: function, startAt: .two, points: (inputPoints, integralPoints, secondIntegralPoints), basePoints: (baseIntegralPoints, baseSecondIntegralPoints))
                    await (inputPoints, integralPoints, secondIntegralPoints) = result.0
                    if let baseIntPoints = result.1.0 {
                        await setBaseIntegral(baseIntPoints)
                    }
                    if let secondBaseIntPoints = result.1.1 {
                        await setSecondBaseIntegral(secondBaseIntPoints)
                    }
                }.value
                done = true
            }
        }
    }
    
    var internalVStack: some View {
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
    }
    
    var menu: some View {
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
        case one
        case two
    }
    
    nonisolated func update(function: Function, startAt: updateStartAt = .zero, points: ([GraphPoint], [GraphPoint], [GraphPoint]), basePoints: ([GraphPoint], [GraphPoint])) async -> (([GraphPoint], [GraphPoint], [GraphPoint]), ([GraphPoint]?, [GraphPoint]?)) {
        var (inputPoints, integralPoints, secondIntegralPoints) = points
        var (baseIntegralPoints, baseSecondIntegralPoints) = basePoints
        
        var resultBaseIntegralPoints: [GraphPoint]? = nil
        var resultBaseSecondIntegralPoints: [GraphPoint]? = nil
        if case .zero = startAt {
            integralPoints = []
            secondIntegralPoints = []
            
            inputPoints = await generateData(function: function)
            baseIntegralPoints = await generateIntegral(for: inputPoints)
            for (_, point) in baseIntegralPoints.enumerated() {
                await integralPoints.append(GraphPoint(xh: point.xh, yv: point.yv+c1))
            }
            
            baseSecondIntegralPoints = await generateIntegral(for: baseIntegralPoints)
            for (_, point) in baseSecondIntegralPoints.enumerated() {
                await secondIntegralPoints.append(GraphPoint(xh: point.xh, yv: point.yv+c2))
            }
            
            resultBaseIntegralPoints = baseIntegralPoints
            resultBaseSecondIntegralPoints = baseSecondIntegralPoints
            
        }
        if case .one = startAt {
            for (i, point) in baseIntegralPoints.enumerated() {
                await integralPoints[i].setY(point.yv + c1)
            }
            for (i, point) in baseSecondIntegralPoints.enumerated() {
                await secondIntegralPoints[i].setY(point.yv + c1 * point.xh + c2 )
            }
        }
        if case .two = startAt {
            for (i, point) in baseSecondIntegralPoints.enumerated() {
                await secondIntegralPoints[i].setY(point.yv + c2)
            }
        }
        return ((inputPoints, integralPoints, secondIntegralPoints), (resultBaseIntegralPoints, resultBaseSecondIntegralPoints))
    }
    
    func setBaseIntegral(_ points: [GraphPoint]) {
        baseIntegralPoints = points
    }
    
    func setSecondBaseIntegral(_ points: [GraphPoint]) {
        baseSecondIntegralPoints = points
    }

}



#Preview {
    HomeView()
}
