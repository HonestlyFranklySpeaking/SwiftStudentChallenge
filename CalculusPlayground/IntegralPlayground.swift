//
//  DerivativePlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI
import Charts

struct IntegralPlayground: View {
    

    @State var function: Function = Function.sine
    @State var inputPoints: [GraphPoint] = []
    @State var xDomain: ClosedRange<Double> = -30...30
    let xDomainConstant: ClosedRange<Double> = -30...30
    
    @State var start: Double = 0
    @State var end: Double = 0
    @State var integral: Double = 0
    @State private var debug: String = ""
    @State var isLeft: Bool = false
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MathGraph(xDomain: $xDomain, serieses: [
                    Series(points: inputPoints, label: "Function")
                ])
                
                Spacer()
                Text("Start")
                Slider(value: $start, in: xDomain)
                Text(start.description)
                Text("End")
                Slider(value: $end, in: xDomain)
                Text(end.description)
                Toggle("Left Hand Riemann Sum", isOn: $isLeft)
                Text(debug)
                Text(integral.description)
            }
            .navigationTitle("Definite Integrals")
            .padding()
            .task {
                await update()

            }
            .toolbar { menu }
        }
        .onChange(of: start) {_, _ in
            Task {
                await update()
            }

        }
        .onChange(of: end) {
            Task {
                await update()
            }
        }
        .onChange(of: isLeft) {
            Task {
                await update()
            }        }
        .onChange(of: function) {
            Task {
                await update()
            }        }
    }
    ///To be done after a change, generates new data and takes definite integral
    func update() async {
        await generateData()
        print("generate data over, entered intagral")
        do {
            integral = try await generateIntegral(of: inputPoints, from: start, to: end, leftHand: isLeft)
        } catch {
            print(error.localizedDescription)
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
    func generateIntegral(of: Array<GraphPoint>, from: Double, to: Double, leftHand: Bool) async throws -> Double {
        print("integrate started")
        let h = Helpers.shared.increment
        //Offset: originally start and end are bounded from (-(30/0.08) to +~400) but wed like it to be from 0 to ~80. Offset does this.
        print("xDomainlower: \(xDomainConstant.lowerBound)")
        let offset = Int(bucket(xDomainConstant.lowerBound, step: h) / h)
        print("offset: \(offset)")
        let start = Int(bucket(from, step: h) / h) - offset
        let end = Int(bucket(to, step: h) / h) - offset
        print("h, from, to, start, end")
        print(h)
        print(from.description)
        print(to.description)
        print(start.description)
        print(end.description)
        var riemannSum: Double = 0
        for i in end >= start ? start ..< end : end ..< start {
            let fxdh = h * (leftHand ? of[i].yv : of[i+1].yv)
            print("f(x): \(of[i].yv) at i: \(i), f(x)dh: \(fxdh), x: \(of[i].xh)")
            riemannSum += fxdh
            
        }
        guard !riemannSum.isNaN else {
            throw integralError.error
        }
        print(riemannSum.description)
        return riemannSum
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
    
}

struct integralError: Error {
    static let error = Self()
}



#Preview {
    IntegralPlayground()
}


