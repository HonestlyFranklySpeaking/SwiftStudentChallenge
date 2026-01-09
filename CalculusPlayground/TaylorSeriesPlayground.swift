//
//  TaylorSeriesPlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI
import Charts

struct TaylorSeriesPlayground: View {
    
    @State var function: Function = Function.sine
    @State var inputPoints: [GraphPoint] = []
    
    @State var taylorExpansionPoints: [GraphPoint] = [.init(xh: -4, yv: 19), .init(xh: 1, yv: -3)]
    
    @State var xDomain: ClosedRange<Double> = -30...30
    
    @State var degree: Int = 5
    @State var center: Double = 6.7
    
    @State private var debug: String = ""
    
    @State private var cachingProgress = 0
    
    @State private var lastPlotTime: TimeInterval = 0
    
    @State private var currentRequestID: UInt64 = 0
    
    @State private var prewarmTask: Task<Void, Never>? = nil
    
    
    @State private var displayedCoefficients: [Double] = []
    @State private var displayedCenter: Double? = nil
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MathGraph(xDomain: $xDomain, inputPoints: $inputPoints, derivedPoints: $taylorExpansionPoints)
                
                Spacer()
                
                if let c = displayedCenter, !displayedCoefficients.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Helpers.shared.attributedPolynomial(coeffs: displayedCoefficients, center: c))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(alignment: .leading)
                }
                
                Stepper("Number of Terms: \(degree)", value: $degree, in: 1...5)
                    .onChange(of: degree) {
                        Task {
                            currentRequestID &+= 1
                            let requestID = currentRequestID
                            do {
                                let display = try await Helpers.shared.computeTaylorData(functionID: function.id, degree: degree, center: center, domain: xDomain, inputs: inputPoints)
                                guard requestID == currentRequestID else { return }
                                taylorExpansionPoints = display.points
                                displayedCoefficients = display.coefficients
                                displayedCenter = display.centerX
                                debug = ""
                            } catch {
                                guard requestID == currentRequestID else { return }
                                taylorExpansionPoints = []
                                displayedCoefficients = []
                                displayedCenter = nil
                                debug = error.localizedDescription
                            }
                        }
                        restartPrewarmer()
                    }
                
                Text("Center: \(Helpers.shared.fixedNumberString(center, fractionDigits: 2))")
                
                Slider(value: $center, in: -10...10, step: Helpers.shared.increment, onEditingChanged: { editing in
                    if !editing {
                        Task {
                            currentRequestID &+= 1
                            let requestID = currentRequestID
                            do {
                                let display = try await Helpers.shared.computeTaylorData(functionID: function.id, degree: degree, center: center, domain: xDomain, inputs: inputPoints)
                                guard requestID == currentRequestID else { return }
                                taylorExpansionPoints = display.points
                                displayedCoefficients = display.coefficients
                                displayedCenter = display.centerX
                                debug = ""
                            } catch {
                                guard requestID == currentRequestID else { return }
                                taylorExpansionPoints = []
                                displayedCoefficients = []
                                displayedCenter = nil
                                debug = error.localizedDescription
                            }
                        }
                    }
                }
                )
                .onChange(of: center) {
                    let now = CACurrentMediaTime()
                    if now - lastPlotTime > Helpers.shared.maxUpdateFrequency {
                        lastPlotTime = now
                        Task {
                            currentRequestID &+= 1
                            let requestID = currentRequestID
                            do {
                                let display = try await Helpers.shared.computeTaylorData(functionID: function.id, degree: degree, center: center, domain: xDomain, inputs: inputPoints)
                                guard requestID == currentRequestID else { return }
                                taylorExpansionPoints = display.points
                                displayedCoefficients = display.coefficients
                                displayedCenter = display.centerX
                                debug = ""
                            } catch {
                                guard requestID == currentRequestID else { return }
                                taylorExpansionPoints = []
                                displayedCoefficients = []
                                displayedCenter = nil
                                debug = error.localizedDescription
                            }
                        }
                    }
                }
                
                Text(debug)
            }
            .navigationTitle("Taylor Series")
            .padding()
            .task {
                await generateData()
                
                currentRequestID &+= 1
                let requestID = currentRequestID
                do {
                    let display = try await Helpers.shared.computeTaylorData(functionID: function.id, degree: degree, center: center, domain: xDomain, inputs: inputPoints)
                    if requestID == currentRequestID {
                        taylorExpansionPoints = display.points
                        print("\n \n DEBUG!!!!!!!!!!!!!! taylor expansion points generated \n \n ")
                        displayedCoefficients = display.coefficients
                        displayedCenter = display.centerX
                        debug = ""
                    }
                } catch {
                    if requestID == currentRequestID {
                        taylorExpansionPoints = []
                        displayedCoefficients = []
                        displayedCenter = nil
                        debug = error.localizedDescription
                    }
                }
                restartPrewarmer()
            }
            .onDisappear {
                prewarmTask?.cancel()
                prewarmTask = nil
            }
            .toolbar {
                
                ToolbarItem {
                    if cachingProgress < 252 {
                        HStack {
                            Text("Caching...")
                                .foregroundColor(.secondary)
                                .padding()
                            
                            // The circular gauge
                            Gauge(value: Double(cachingProgress), in: 0...252) {
                                // Empty label, as we have a custom one in the HStack
                            }
                            .gaugeStyle(ToolbarGauge())
                            .frame(width: 34, height: 34)
                        }
                        .fixedSize()
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        
                    }
                }
                
                ToolbarSpacer()
                
                ToolbarItem {
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
                    }
                    .onChange(of: function) { _, _ in
                        Task {
                            await generateData()
                            currentRequestID &+= 1
                            let requestID = currentRequestID
                            do {
                                let display = try await Helpers.shared.computeTaylorData(functionID: function.id, degree: degree,center: center, domain: xDomain, inputs: inputPoints)
                                
                                guard requestID == currentRequestID else { return }
                                taylorExpansionPoints = display.points
                                displayedCoefficients = display.coefficients
                                displayedCenter = display.centerX
                                debug = ""
                            } catch {
                                guard requestID == currentRequestID else { return }
                                taylorExpansionPoints = []
                                displayedCoefficients = []
                                displayedCenter = nil
                                debug = error.localizedDescription
                            }
                        }
                        restartPrewarmer()
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
    
    private func restartPrewarmer() {
        withAnimation {
            cachingProgress = 0
        }
        
        
        prewarmTask?.cancel()
        prewarmTask = Task(priority: .background) {
            await runContinuousPrewarmer()
        }
    }
    
    func runContinuousPrewarmer() async {
        print("[PrewarmLoop] Starting simplified prewarmer")
        
        let refinedDomain: ClosedRange<Double> = -80.0...80.0
        let bucketStep: Double = Helpers.shared.increment
        let allowedCenterRange: ClosedRange<Double> = -10.0...10.0
        
        var depth: Int = 4
        
        // All functions to cycle through (stable order)
        let allFunctions: [Function] = [Function.sine, Function.exp, Function.square, Function.naturalLog, Function.humpy, Function.inverse]
        
        // Snapshot current state
        let currentFunc = function
        let currentFuncID = currentFunc.id
        let deg = degree
        let inputsCopy = inputPoints
        let currentCenterBucket = bucket(center, step: bucketStep)
        
        // 1) Current function: small band around current center, depth expanding
        if allowedCenterRange.contains(currentCenterBucket) {
            print("PREWARM STAGE 1: Expanding depth from \(currentCenterBucket)")
            let ks = [0] + Array(1...depth).flatMap { [ -$0, $0 ] }
            var debugArray: [Double] = []
            
            for k in ks {
                if Task.isCancelled { return }
                let c = currentCenterBucket + Double(k) * bucketStep
                debugArray.append(c)
                if !allowedCenterRange.contains(c) { continue }
                
                await Helpers.shared.ensureTaylorPoints(functionID: currentFuncID,
                                                        degree: deg,
                                                        centerBucket: c,
                                                        refinedDomain: refinedDomain,
                                                        inputs: inputsCopy)
                await Task.yield()
                
                cachingProgress += 1
            }
            print("STAGE 1 COMPLETE: ensured inputs \(debugArray)")
        }
        
        print("PREWARM STAGE 2: Ensuring inputs for all other functions")
        for f in allFunctions where f.id != currentFuncID {
            if Task.isCancelled { return }
            if allowedCenterRange.contains(currentCenterBucket) {
                await Helpers.shared.ensureTaylorPoints(functionID: f.id,
                                                        degree: deg,
                                                        centerBucket: currentCenterBucket,
                                                        refinedDomain: refinedDomain,
                                                        inputs: inputsCopy)
            }
            await Task.yield()
        }
        print("STAGE 2 COMPLETE")
        
        // Small pause to keep background work gentle
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        print("PREWARM STAGE 3: Starting extended depth expansion.")
        var completedBranches = 0
        
        while !Task.isCancelled && completedBranches < 2 {
            depth += 1
            completedBranches = 0
            
            let shell: [Double] = [
                currentCenterBucket + Double(depth) * bucketStep,
                currentCenterBucket - Double(depth) * bucketStep
            ]
            var debugArray: [Double] = []
            
            for c in shell {
                if Task.isCancelled { return }
                if !allowedCenterRange.contains(c) {
                    completedBranches += 1
                    continue
                }
                await Helpers.shared.ensureTaylorPoints(functionID: currentFuncID,
                                                        degree: deg,
                                                        centerBucket: c,
                                                        refinedDomain: refinedDomain,
                                                        inputs: inputsCopy)
                debugArray.append(c)
                await Task.yield()
            }
            print("PREWARM added inputs \(debugArray) to cache.")
            
            cachingProgress += (2 - completedBranches)
        }
        
        withAnimation {
            cachingProgress += 1
        }
        
        print("<<<EXTENDED EXPANSION COMPLETE>>>")
    }
}





#Preview {
    TangentLinePlayground()
}

