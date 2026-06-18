//
//  TangentLinePlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI
import Charts

struct TangentLinePlayground: View {
    @State var function: Function = Function.naturalLog
    @State var inputPoints: [GraphPoint] = []
    
    @State var tangentLine: [GraphPoint] = [.init(xh: -4, yv: 19), .init(xh: 1, yv: -3)]
    
    @State var xDomain: ClosedRange<Double> = -30...30
    
    @State var center: Double = 6.7
    
    @State private var debug: String = ""
    
    @State private var showFunctionOptions: Bool = false
    
    @State private var lastPlotTime: TimeInterval = 0
    
    @State private var currentRequestID: UInt64 = 0
    
    @State private var displayedCoefficients: [Double] = []
    @State private var displayedCenter: Double? = nil
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MathGraph(serieses: [
                    Series(points: inputPoints, label: "Function"),
                    Series(points: tangentLine, label: "Tangent Line")
                ])
                
                Spacer()
                
                if let c = displayedCenter, !displayedCoefficients.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Helpers.shared.attributedPolynomial(coeffs: displayedCoefficients, center: c))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(alignment: .leading)
                }
                
                Text("Center: \(Helpers.shared.fixedNumberString(center, fractionDigits: 2))")
                
                Slider(value: $center, in: -10...10, step: Helpers.shared.increment, onEditingChanged: { editing in
                    if !editing {
                        Task { await recompute() }
                    }
                }
                )
                .onChange(of: center) {
                    let now = CACurrentMediaTime()
                    if now - lastPlotTime > Helpers.shared.maxUpdateFrequency {
                        lastPlotTime = now
                        Task { await recompute() }
                    }
                }
                
                Text(debug)
            }
            .navigationTitle("Tangent Line")
            .padding()
            .task {
                await generateData()
                
                await recompute()
            }
            .onChange(of: function) { _, _ in
                Task {
                    await generateData()
                    await recompute()
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
    
    
    
    /// Recomputes the tangent line (degree-1 Taylor expansion) for the current
    /// function/center and publishes it. Bumps `currentRequestID` first and
    /// discards stale results so rapid slider changes can't clobber newer data.
    func recompute() async {
        currentRequestID &+= 1
        let requestID = currentRequestID
        do {
            let display = try await Helpers.shared.computeTaylorData(functionID: function.id, degree: 1, center: center, domain: xDomain, inputs: inputPoints)
            guard requestID == currentRequestID else { return }
            tangentLine = display.points
            displayedCoefficients = display.coefficients 
            displayedCenter = display.centerX
            debug = ""
        } catch {
            guard requestID == currentRequestID else { return }
            tangentLine = []
            displayedCoefficients = []
            displayedCenter = nil
            debug = error.localizedDescription
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
    TangentLinePlayground()
}

