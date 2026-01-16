//
//  DerivativePlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI
import Charts
import RangeSlider

struct IntegralPlayground: View {
    enum IntegralStatus {
        case pending
        case done
    }
    
    @State var integralState: IntegralStatus = .done
    let increment: Double = 0.005
    @State var function: Function = Function.sine
    @State var inputPoints: [GraphPoint] = []
    @State var xDomain: ClosedRange<Double> = -30...30
    let xDomainConstant: ClosedRange<Double> = -30...30
    
    @State var start: Double = 0.25
    @State var end: Double = 0.75
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
                RangeSlider(lowerValue: $start, upperValue: $end, step: 0.01)
                Text("\(mapRangeSlider( start, range: xDomainConstant).description) - \(mapRangeSlider( end, range: xDomainConstant).description)")
                Toggle("Left Hand Riemann Sum", isOn: $isLeft)
                Text(debug)
                integralEquation
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
        integralState = .pending
        await generateData()
        print("generate data over, entered intagral")
        do {
            integral = try await generateIntegral(of: inputPoints, from: mapRangeSlider(start, range: xDomainConstant), to: mapRangeSlider(end, range: xDomainConstant), leftHand: isLeft)
        } catch {
            print(error.localizedDescription)
        }
        integralState = .done
    }
    func generateData() async {
        let f = function
        let range: ClosedRange<Double> = xDomainConstant
        let step: Double = increment
        let points: [GraphPoint] = await Task.detached(priority: .utility) {
            await makeInputs(for: f, range: range, step: step)
        }.value
        inputPoints = points
        print("\n Generated \(points.count) points for function \(f.id.uuidString.prefix(6)) \n")
    }
    func generateIntegral(of: Array<GraphPoint>, from: Double, to: Double, leftHand: Bool) async throws -> Double {
        print("integrate started")
        let h = of[1].xh - of[0].xh
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
        if end < start { riemannSum *= -1 }
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
    var integralEquation: some View {
        HStack {
            HStack(spacing: 0.5) {
                Text("∫")
                    .font(.largeTitle)
                VStack {
                    Text(String(format: "%.2f", bucket(mapRangeSlider(end, range: xDomainConstant), step: 0.01)))
                        .font(.caption)
                        .padding(0.7)
                    Text(String(format: "%.2f", bucket(mapRangeSlider(start, range: xDomainConstant), step: 0.01)))
                        .font(.caption)
                        .padding(0.5)
                }
            }
                
                function.visualizationClosure()
            if integralState == .done {
                Text("dx ≈ \((String(format: "%.2f", bucket(integral, step: 0.01))))")
            } else {
                Text("...")
            }
        }
    }
    func mapRangeSlider(_ value: Double, range: ClosedRange<Double>) -> Double {
        return value * (range.upperBound - range.lowerBound) + range.lowerBound
    }
}

struct integralError: Error {
    static let error = Self()
}



#Preview {
    IntegralPlayground()
}


