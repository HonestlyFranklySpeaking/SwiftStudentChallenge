//
//  TaylorSeriesPlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI
import Charts

struct DerivativePlayground: View {
    
    @State var function: Function = Function.naturalLog
    @State var inputPoints: [GraphPoint] = []
    // taylorExpansio n Function is no longer used; remove to avoid state churn
    // @State var taylorExpansion: Function? = nil
    @State var taylorExpansionPoints: [GraphPoint] = [.init(xh: 0, yv: 8), .init(xh: 3, yv: 18)]
    
    @State var graphScale: Double = 30
    
    @State private var xDomain: ClosedRange<Double> = -30...30
    @State private var yDomain: ClosedRange<Double> = -30...30
    @State private var lastDragTranslation: CGSize = .zero
    
    
    @State private var debug: String = ""
    
    // Throttle for slider-driven updates
    @State private var lastPlotTime: TimeInterval = 0
    
    // Coalescing id to drop stale results
    @State private var currentRequestID: UInt64 = 0
    
    // Continuous background prewarmer task
    @State private var prewarmTask: Task<Void, Never>? = nil
    
    // Pinch-to-zoom state
    @State private var pinchScale: CGFloat = 1.0
    @State private var pinchBaseXDomain: ClosedRange<Double> = -30...30
    @State private var pinchBaseYDomain: ClosedRange<Double> = -30...30
    
    private func invertedScale(from sliderValue: Double) -> Double {
        let clamped = max(5, min(100, sliderValue))
        return 105 - clamped // 5 -> 100, 100 -> 5
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Chart {
                    RuleMark(x: .value("Origin X", 0))
                        .foregroundStyle(.gray.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    
                    RuleMark(y: .value("Origin Y", 0))
                        .foregroundStyle(.gray.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    
                    ForEach(inputPoints) { point in
                        PointMark(
                            x: .value("X", point.xh),
                            y: .value("Y", point.yv)
                        )
                        .symbol(.circle)
                        .foregroundStyle(.blue)
                        .symbolSize(25)
                    }
                    
                    ForEach(taylorExpansionPoints) { point in
                        LineMark(
                            x: .value("X", point.xh),
                            y: .value("Y", point.yv)
                        )
                        .interpolationMethod(.linear)
                    }
                    .foregroundStyle(Gradient(colors: [.pink, .purple]))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                .chartXScale(domain: xDomain)
                .chartYScale(domain: yDomain)
                .chartPlotStyle { plotArea in
                    plotArea
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 30).fill(Helpers.shared.gradient)
                            }
                        }
                        .contentShape(Rectangle())
                        .clipped()
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                }
                .chartXAxis {
                    Helpers.shared.axisMarks(for: invertedScale(from: graphScale), position: .bottom)
                }
                .chartYAxis {
                    Helpers.shared.axisMarks(for: invertedScale(from: graphScale), position: .leading)
                }
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 12) {
                        Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                        Slider(value: $graphScale, in: 5...100, step: 1)
                            .onChange(of: graphScale) { _, newScale in
                                let centerX = (xDomain.lowerBound + xDomain.upperBound) / 2
                                let centerY = (yDomain.lowerBound + yDomain.upperBound) / 2
                                let half = invertedScale(from: newScale)
                                xDomain = (centerX - half)...(centerX + half)
                                yDomain = (centerY - half)...(centerY + half)
                            }
                        Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 220)
                    .padding(10)
                }
                .frame(height: 340)
                .padding(.horizontal, 8)
                // Attach separate gestures without SimultaneousGesture
                .gesture(dragGesture)
                .gesture(magnificationGesture)
                
                Spacer()
                
                Stepper("Number of Terms: \(degree)", value: $degree, in: 1...5)
                    .onChange(of: degree) {
                        Task { await plotGraph() }
                        restartPrewarmer()
                    }
                
                Text("Center: \(center)")
                
                Slider(
                    value: $center,
                    in: -10...10,
                    step: 0.2,
                    onEditingChanged: { editing in
                        isSliding = editing
                        if !editing {
                            Task { await plotGraph() }
                            restartPrewarmer()
                        }
                    }
                )
                .onChange(of: center) {
                    if isSliding {
                        let now = CACurrentMediaTime()
                        if now - lastPlotTime > 0.1 {
                            lastPlotTime = now
                            Task { await plotGraph() }
                        }
                    }
                }
                
                Text(debug)
            }
            .navigationTitle("Taylor Series")
            .padding()
            .task {
                await generateData()
                let half = invertedScale(from: graphScale)
                xDomain = (-half)...(half)
                yDomain = (-half)...(half)
                pinchBaseXDomain = xDomain
                pinchBaseYDomain = yDomain
                await plotGraph()
                
                restartPrewarmer()
            }
            .onDisappear {
                // Stop prewarmer if the view disappears
                prewarmTask?.cancel()
                prewarmTask = nil
            }
            .toolbar {
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
                        await generateData()
                        await plotGraph()
                    }
                    restartPrewarmer()
                }
            }
        }
    }
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let delta = value.translation - lastDragTranslation
                lastDragTranslation = value.translation
                
                let xRange = xDomain.upperBound - xDomain.lowerBound
                let yRange = yDomain.upperBound - yDomain.lowerBound
                let xDelta = xRange * Double(delta.width) / 300.0
                let yDelta = yRange * Double(-delta.height) / 300.0
                
                xDomain = (xDomain.lowerBound - xDelta)...(xDomain.upperBound - xDelta)
                yDomain = (yDomain.lowerBound - yDelta)...(yDomain.upperBound - yDelta)
                
                // Keep pinch base in sync so pinch continues smoothly after pan
                pinchBaseXDomain = xDomain
                pinchBaseYDomain = yDomain
            }
            .onEnded { _ in
                lastDragTranslation = .zero
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // Clamp magnification factor to avoid extreme zoom
                // 0.2x to 5x relative to the base domain
                let clamped = CGFloat(max(0.2, min(5.0, value)))
                pinchScale = clamped
                
                let baseX = pinchBaseXDomain
                let baseY = pinchBaseYDomain
                
                let centerX = (baseX.lowerBound + baseX.upperBound) / 2.0
                let centerY = (baseY.lowerBound + baseY.upperBound) / 2.0
                let halfX = (baseX.upperBound - baseX.lowerBound) / 2.0
                let halfY = (baseY.upperBound - baseY.lowerBound) / 2.0
                
                let newHalfX = Double((halfX) / Double(clamped))
                let newHalfY = Double((halfY) / Double(clamped))
                
                var newX = (centerX - newHalfX)...(centerX + newHalfX)
                var newY = (centerY - newHalfY)...(centerY + newHalfY)
                
                let newHalf = max(newHalfX, newHalfY)
                let proposedSlider = 105 - newHalf
                let clampedSlider = max(5, min(100, proposedSlider))
                let halfFromSlider = invertedScale(from: clampedSlider)
                
                let cx = (newX.lowerBound + newX.upperBound) / 2
                let cy = (newY.lowerBound + newY.upperBound) / 2
                newX = (cx - halfFromSlider)...(cx + halfFromSlider)
                newY = (cy - halfFromSlider)...(cy + halfFromSlider)
                
                xDomain = newX
                yDomain = newY
                graphScale = clampedSlider
            }
            .onEnded { _ in
                pinchBaseXDomain = xDomain
                pinchBaseYDomain = yDomain
                pinchScale = 1.0
            }
    }
    
    // MARK: - Data
    
    func generateData() async {
        let f = function
        let range: ClosedRange<Double> = -30.0...30.0
        let step: Double = 0.05
        let points: [GraphPoint] = await Task.detached(priority: .utility) {
            await makeInputs(for: f, range: range, step: step)
        }.value
        inputPoints = points
        print("/n Generated \(points.count) points for function \(f.id.uuidString.prefix(6)) /n")
    }
    
    func plotGraph() async {
        currentRequestID &+= 1
        let requestID = currentRequestID
        
        // Snapshot state
        let funcID = function.id
        let deg = degree
        let centerValue = center
        let domain = xDomain
        let inputsCopy = inputPoints
        
        debug = ""
        
        let result = await Helpers.shared.computeTaylorPoints(functionID: funcID,
                                                              degree: deg,
                                                              center: centerValue,
                                                              domain: domain,
                                                              inputs: inputsCopy)
        // Drop stale results
        guard requestID == currentRequestID else {
            print("Dropped stale result id:\(requestID) current:\(currentRequestID)")
            return
        }
        
        switch result {
        case .success(let points):
            taylorExpansionPoints = points
        case .failure(let error):
            debug = error.localizedDescription
        }
    }
    
    
    private func restartPrewarmer() {
        prewarmTask?.cancel()
        prewarmTask = Task(priority: .background) {
            await runContinuousPrewarmer()
        }
    }
    
    // Sequence:
    // 1) Current function: small band around current center
    // 2) Other functions: exactly one center (current center bucket)
    // 3) Continue expanding current function only
    func runContinuousPrewarmer() async {
        print("[PrewarmLoop] Starting simplified prewarmer")
        
        let refinedDomain: ClosedRange<Double> = -80.0...80.0
        let bucketStep: Double = 0.2
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
            }
            print("STAGE 1 COMPLETE: ensured inputs \(debugArray)")
        }
        
        // 2) Other functions: exactly one center each
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
        }
        
        print("<<<EXTENDED EXPANSION COMPLETE>>>")
    }
}



// Restore the CGSize - operator for panning math
private extension CGSize {
    static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }
}

#Preview {
    TaylorSeriesPlayground()
}
