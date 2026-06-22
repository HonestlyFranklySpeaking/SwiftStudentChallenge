//
//  IntegralPlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI; import SwiftData
import Charts

struct IntegralPlayground: View {
    @State var done: Bool = false
    @State var bigDone: Bool = false
    @State var c1: Double = 0
    @State var c2: Double = 0
    @State var function: Function = Function.sine
    @State var inputPoints: [GraphPoint] = []
    @State var showFunctionOptions: Bool = false
    
    @State var baseIntegralPoints: [GraphPoint] = []
    @State var baseSecondIntegralPoints: [GraphPoint] = []
    
    @State var integralPoints: [GraphPoint] = []
    
    
    
    @State var secondIntegralPoints: [GraphPoint] = []
    
    @State var xDomain: ClosedRange<Double> = -30...30
    
    
    @State private var debug: String = ""
    
    @State var lastUpdateDate: Date = Date.distantPast
    
    var body: some View {
        NavigationStack {
            internalVStack
                .navigationTitle("Integrals")
                .padding()
        }
        .task {
            bigDone = false
            await plotData(startAt: .zero)
            bigDone = true
        }
        .onChange(of: function) { _, _ in
            Task {
                bigDone = false
                await plotData(startAt: .zero)
                bigDone = true
            }
        }
        .onChange(of: c1) { j, k in
            Task {
                await plotData(startAt: .one(c0: c1, c1: c2))
            }
        }
        .onChange(of: c2) { _, _ in
            Task {
                //Starts at step 2 because only integral 2 is affected
                await plotData(startAt: .two(c0: c1, c1: c2))
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
    
    var internalVStack: some View {
        VStack(spacing: 12) {
            if bigDone { MathGraph(serieses: [
                Series(points: inputPoints, label: "Function"),
                Series(points: integralPoints, label: "Integral"),
                Series(points: secondIntegralPoints, label: "Second Integral"),
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
        
    }
    
    
    func plotData(startAt: updateStartAt) async {
        done = false
        let startDate = Date()
        await Task.detached(name: "Change after c1(2) modification", priority: .high) {
            let result = await update(function: function, startAt: startAt, points: (inputPoints, integralPoints, secondIntegralPoints), basePoints: (baseIntegralPoints, baseSecondIntegralPoints))
            
            await setPoint(result, date: startDate)
            
            
        }.value
        done = true
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
            baseIntegralPoints = (try? await generateFastIntegral(for: inputPoints)) ?? []
            for point in baseIntegralPoints {
                await integralPoints.append(GraphPoint(xh: point.xh, yv: point.yv+c1, asynch: ()))
            }
            
            baseSecondIntegralPoints = (try? await generateFastIntegral(for: baseIntegralPoints)) ?? []
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
    func setPoint(_ points: ([GraphPoint]?, [GraphPoint]?, [GraphPoint]?, [GraphPoint]?, [GraphPoint]?), date: Date?) async {
        
        if let unwrappedDate = date {
            if unwrappedDate < lastUpdateDate {
                return
            }
        }
        
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
        
        if let unwrappedDate = date {
            lastUpdateDate = unwrappedDate
        }
    }
}



#Preview {
    HomeView()
}
