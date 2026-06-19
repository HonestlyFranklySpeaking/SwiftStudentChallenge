//
//  MathCode.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 23/12/25.
//

import Foundation
import SwiftUI


///Represents a ClosedRange<Double> that may be reversed(-1...-4)
struct ReversibleRange {
    var range: ClosedRange<Double>
    var isReverse: Bool = false
    init(_ range: ClosedRange<Double>, reverse: Bool = false) {
        self.range = range
        self.isReverse = reverse
    }
    init(_ start: Double, _ end: Double) {
        if start > end {
            range = end ... start
            isReverse = true
        } else {
            range = start ... end
        }
    }
}

///Represents a point on a graph, with xh and yv as x and y
class GraphPoint: Identifiable, CustomStringConvertible {
    var id: UUID = UUID()
    ///x
    var xh: Double
    ///y
    var yv: Double
    
    nonisolated init(xh: Double, yv: Double) {
        self.xh = xh
        self.yv = yv
    }
    
    nonisolated init (xh: Double, yv: Double, asynch: Void) async {
        self.xh = xh
        self.yv = yv
    }
    
    var description: String {
        "(\(xh), \(yv))"
    }
}

///Represents a mathematical function
class Function: Identifiable, Hashable {
    static var functionDictionary: [Function: String] = [
        identity: "Identity",
        sine: "Sine",
        square: "Square",
        inverse: "Inverse",
        exp: "Exponential",
        naturalLog: "Natural Log",
        humpy: "Polynomial"
    ]
    
    //To be expanded upon
    
    nonisolated let id: UUID = UUID()
    var derivative: Function? = nil
    ///This gives a view that looks like the function, like Text("x") for identity
    nonisolated let mathText: String?
    let transform: (Double) -> Double
    init(transform: @escaping (Double) -> Double, text: String = "Ifshown: ERROR") {
        self.transform = transform
        self.mathText = text
    }
    
    static var allFunctions: [Function] = [.exp, .sine, .square, .inverse, .identity, .naturalLog, .humpy]
    
    static let identity: Function = .init(transform: { $0 }, text: "x")
    static let sine: Function = .init(transform: { sin($0) }, text: "sin(x)")
    static let square: Function = .init(transform: { $0 * $0 }, text: "x^2")
    static let inverse: Function = .init(transform: { 1 / $0 }, text: "1/x")
    static let exp: Function = .init(transform: { pow(2.71828, $0) }, text: "e^x")
    
    static let naturalLog: Function = .init(transform: { log($0) }, text: "ln(x)")
    static let zero: Function = .init(transform: { 0 * $0 }, text: "0x")

    static let humpy: Function = .init(transform: {
        let x = $0 / 1.5
        let a = (x+10)*(x+10)*(x-15)
        let b = (x+30)*(x+3)*(x-10)*(x-30)
        return a * b / 1200000
    }, text: "p(x)")
    
    static func == (lhs: Function, rhs: Function) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum computeError: Error, LocalizedError {
    case insufficientData
    
    
    var errorDescription: String? {
        switch self {
        case .insufficientData: return "Insufficient data to compute the requested Taylor series."
        }
    }
}

enum SeriesGenerationError: Error, LocalizedError {
    case insufficientData
    case invalidDegree
    case missingCenter
    case missingSymetricPoints
    case failedValueMap
    case failedDerivative(order: Int)
    
    var errorDescription: String? {
        switch self {
        case .insufficientData: return "Insufficient data to compute the requested Taylor series."
        case .invalidDegree: return "Invalid degree. Supported degrees are 1 through 5."
        case .missingCenter: return "Missing center data point."
        case .missingSymetricPoints: return "Unable to find symetric data points."
        case .failedValueMap: return "Failed value mapping"
        case .failedDerivative(let order): return "Failed to compute derivative \(order)."
        }
    }
}

// Pure helper to generate inputs for any function without touching UI state.
// Filters out non-finite values to avoid NaN/inf poisoning.
func makeInputs(for function: Function, range: ClosedRange<Double>, step: Double) -> [GraphPoint] {
    let xs = stride(from: range.lowerBound, through: range.upperBound, by: step)
    return xs.compactMap { x in
        let y = function.transform(x)
        guard y.isFinite else { return nil }
        return GraphPoint(xh: x, yv: y)
    }
}

// Result bundle carrying the Taylor series function, its coefficients, and the center used.
struct TaylorSeriesResult {
    let series: Function
    // Coefficients already include factorial divisors: a0, a1, ..., an
    // Polynomial is sum_i a_i * (x - centerX)^i
    let coefficients: [Double]
    let centerX: Double
}

/// Compact cache payload: a Taylor polynomial is fully described by its
/// coefficients and center. Display points are sampled on demand
/// (`sampleTaylorPoints`) so cache entries stay tiny and prewarming never pays
/// point-generation cost for centers that are never shown.
struct CachedSeries: Sendable {
    let coefficients: [Double]
    let centerX: Double
}

/// Horner evaluation of a Taylor polynomial about `centerX`.
func evaluateTaylor(coefficients: [Double], centerX: Double, at input: Double) -> Double {
    let x = input - centerX
    var sum = 0.0
    for i in stride(from: coefficients.count - 1, through: 0, by: -1) {
        sum = sum * x + coefficients[i]
    }
    return sum
}

/// Samples a cached polynomial into display points over [start, end].
/// Matches the previous fixed ±80 / 800-step sampling exactly.
func sampleTaylorPoints(_ cached: CachedSeries,
                        start: Double = -80,
                        end: Double = 80,
                        count: Int = 800) -> [GraphPoint] {
    let step = (end - start) / Double(count)
    return stride(from: start, through: end, by: step).map { x in
        GraphPoint(xh: x, yv: evaluateTaylor(coefficients: cached.coefficients, centerX: cached.centerX, at: x))
    }
}

enum integralError: Error, LocalizedError {
    case invalidSum
    case invalidRange
}


nonisolated func generateIntegral(for inputs: [GraphPoint]) async -> [GraphPoint] {
    // Ensure we have at least two points to form a trapezoid
    guard inputs.count >= 2 else { return [] }
    
    var integralPoints: [GraphPoint] = []
    
    // Iterate through the points to calculate ∫ from 0 to n for all n
    for h in 0..<(inputs.count) {
        do {
            try await integralPoints.append(GraphPoint(xh: inputs[h].xh, yv: Double(await riemannSum(for: inputs, range: ReversibleRange(0, inputs[h].xh)).0)))
        } catch integralError.invalidRange {
            print("InvalidRange")
        } catch {
        }
    }
    return integralPoints
}

nonisolated func generateFastIntegral(for inputs: [GraphPoint]) async throws -> [GraphPoint] {
    
    var positiveIntegralPoints: [GraphPoint] = []
    var negativeIntegralPoints: [GraphPoint] = []

    var positiveIntegralCurrent: Double = 0
    var negativeIntegralCurrent: Double = 0
    
    print("\n INTEGRAl: ")
    
    
    let positiveDomain = await 0.0 ... inputs.last!.xh
    let negativeDomain = await inputs.first!.xh ... 0.0
    
    var positiveLeftHand: [GraphPoint] = []
    var negativeLeftHand: [GraphPoint] = []
    
    for i in inputs {
        if await positiveDomain.contains(i.xh) {
            positiveLeftHand.append(i)
        } else if await negativeDomain.contains(i.xh) {
            negativeLeftHand.append(i)
        }
    }
    
    ///////////////////////////////////////////
    
    let h = await positiveLeftHand[1].xh - positiveLeftHand[0].xh
    print("H: \(h)")
    
    for leftHandPoint in positiveLeftHand {
        print("One rect added")
        
        
        await positiveIntegralCurrent += leftHandPoint.yv * h
        await positiveIntegralPoints.append(GraphPoint(xh: leftHandPoint.xh, yv: positiveIntegralCurrent))
        print("rect area: \(await leftHandPoint.yv * h)")
    }
    //////////
    
    
    print("H: \(h)")
    
    for leftHandPoint in negativeLeftHand {
        print("One rect added")
        
        
        await negativeIntegralCurrent += leftHandPoint.yv * h
        await negativeIntegralPoints.append(GraphPoint(xh: leftHandPoint.xh, yv: negativeIntegralCurrent))
        print("rect area: \(await leftHandPoint.yv * h)")
    }
    
    
    var reversedNegativeIntegralPoints: [GraphPoint] = negativeIntegralPoints.reversed()
    reversedNegativeIntegralPoints.append(contentsOf: positiveIntegralPoints)
    return reversedNegativeIntegralPoints

}

nonisolated func riemannSum(for inputs: [GraphPoint], range range_r: ReversibleRange) async throws -> (Double, [GraphPoint]) {
    print("\n INTEGRAl: ")
    let range = range_r.range
    var isInRange = inputs.map() {_ in false}
    for (i, point) in inputs.enumerated() {
        if await (point.xh >= range.lowerBound) { if await (point.xh < range.upperBound) {
            isInRange[i] = true
        }}
    }
    
    let leftHand = inputs.enumerated().filter() { isInRange[$0.0] }.map() { $0.1 }
    // prevents index out of range error
    guard leftHand.count > 2 else {
        return (0, [])
    }
    
    let domain = await inputs.first!.xh ... inputs.last!.xh

    guard domain.contains(range_r.range) else {
        throw integralError.invalidRange
    }
    
    
    let h = await leftHand[1].xh - leftHand[0].xh
    print("H: \(h)")
    
    var sum = 0.0
    var rectangles = [] as [GraphPoint]
    for leftHandPoint in leftHand {
        print("One rect added")
        
        
        
        sum += ( await leftHandPoint.yv * h )
        
        print("rect area: \(await leftHandPoint.yv * h)")
        await rectangles.append(GraphPoint(xh: leftHandPoint.xh + h * 1/300, yv: leftHandPoint.yv))
        await rectangles.append(GraphPoint(xh: leftHandPoint.xh + h * 299/300, yv: leftHandPoint.yv))
        
    }
    
    guard !sum.isNaN else {
        throw integralError.invalidSum
    }
    
    if range_r.isReverse {
        sum *= -1
    }
    
    print("SUM: \(sum) \n")
    return (sum, rectangles)
}


func mapDerivative(for inputs: [GraphPoint]) async throws -> [GraphPoint] {
    guard !inputs.isEmpty else { throw computeError.insufficientData }
    
    var derivatives = [GraphPoint]()
    
    for i in 0..<(inputs.count - 1) {
        let dy = inputs[i + 1].yv - inputs[i].yv
        let dx = inputs[i + 1].xh - inputs[i].xh
        
        derivatives.append(GraphPoint(xh: inputs[i].xh, yv: (dy/dx)))
    }
    
    
    return derivatives
}


// Generates the Taylor series polynomial (as a Function) centered at `center`,
// and returns the coefficients (already factorial-normalized) and the centerX actually used.
func generateTaylorSeriesResult(for inputs: [GraphPoint], degree: Int, center: Double) async throws -> TaylorSeriesResult {
    guard !inputs.isEmpty else { throw SeriesGenerationError.insufficientData }
    guard (1...5).contains(degree) else { throw SeriesGenerationError.invalidDegree }
    
    // Inputs come from makeInputs: finite samples on a regular grid (spacing =
    // increment). Instead of re-sorting and linear-scanning for every value, key
    // them by grid index for O(1) lookups — this dominates per-call cost now that
    // prewarming computes coefficients without sampling points.
    let step = Helpers.shared.increment
    let tol = 11.0/20.0 * step
    func gridIndex(_ x: Double) -> Int { Int((x / step).rounded()) }

    var yByIndex = [Int: Double](minimumCapacity: inputs.count)
    for p in inputs where p.yv.isFinite { yByIndex[gridIndex(p.xh)] = p.yv }
    func y(at targetX: Double) -> Double? { yByIndex[gridIndex(targetX)] }

    // The sampled point nearest the requested center is the expansion point.
    guard let centerPoint = inputs.min(by: { abs($0.xh - center) < abs($1.xh - center) }),
          abs(centerPoint.xh - center) <= tol else {
        throw SeriesGenerationError.missingCenter
    }
    let centerX = centerPoint.xh
    let f0 = centerPoint.yv

    // Smallest positive offset whose mirror across centerX is also present.
    var spacing: Double? = nil
    for p in inputs {
        let offset = p.xh - centerX
        if offset > tol, y(at: centerX - offset) != nil {
            if spacing == nil || offset < spacing! { spacing = offset }
        }
    }
    guard let h = spacing else { throw SeriesGenerationError.missingSymetricPoints }
    
    func hasPair(k: Int) -> Bool {
        let step = Double(k) * h
        return y(at: centerX + step) != nil && y(at: centerX - step) != nil
    }
    func requireY(_ x: Double) throws -> Double {
        guard let val = y(at: x) else { throw SeriesGenerationError.failedValueMap }
        return val
    }
    func pair(_ k: Int) throws -> (Double, Double) {
        let step = Double(k) * h
        let fp = try requireY(centerX + step)
        let fm = try requireY(centerX - step)
        return (fm, fp)
    }
    
    func derivative1() throws -> Double {
        guard hasPair(k: 1) else { throw SeriesGenerationError.failedDerivative(order: 1) }
        let (fm1, fp1) = try pair(1)
        return (fp1 - fm1) / (2 * h)
    }
    func derivative2() throws -> Double {
        guard hasPair(k: 1) else { throw SeriesGenerationError.failedDerivative(order: 2) }
        let (fm1, fp1) = try pair(1)
        return (fp1 - 2 * f0 + fm1) / (h * h)
    }
    func derivative3() throws -> Double {
        guard hasPair(k: 1), hasPair(k: 2) else { throw SeriesGenerationError.failedDerivative(order: 3) }
        let (fm2, fp2) = try pair(2)
        let (fm1, fp1) = try pair(1)
        let numerator = (fp2 - 2*fp1 + 2*fm1 - fm2)
        return numerator / (2 * pow(h, 3))
    }
    func derivative4() throws -> Double {
        guard hasPair(k: 1), hasPair(k: 2) else { throw SeriesGenerationError.failedDerivative(order: 4) }
        let (fm2, fp2) = try pair(2)
        let (fm1, fp1) = try pair(1)
        return (fm2 - 4*fm1 + 6*f0 - 4*fp1 + fp2) / pow(h, 4)
    }
    func derivative5() throws -> Double {
        guard hasPair(k: 1), hasPair(k: 2), hasPair(k: 3) else { throw SeriesGenerationError.failedDerivative(order: 5) }
        let (fm3, fp3) = try pair(3)
        let (fm2, fp2) = try pair(2)
        let (fm1, fp1) = try pair(1)
        let numerator = (fp3 - 4*fp2 + 5*fp1 - 5*fm1 + 4*fm2 - fm3)
        return numerator / (2 * pow(h, 5))
    }
    
    var d1 = 0.0, d2 = 0.0, d3 = 0.0, d4 = 0.0, d5 = 0.0
    if degree >= 1 { d1 = try derivative1() }
    if degree >= 2 { d2 = try derivative2() }
    if degree >= 3 { d3 = try derivative3() }
    if degree >= 4 { d4 = try derivative4() }
    if degree >= 5 { d5 = try derivative5() }
    
    var coeffs: [Double] = []
    switch degree {
    case 1: coeffs = [f0, d1]
    case 2: coeffs = [f0, d1, d2 / 2]
    case 3: coeffs = [f0, d1, d2 / 2, d3 / 6]
    case 4: coeffs = [f0, d1, d2 / 2, d3 / 6, d4 / 24]
    case 5: coeffs = [f0, d1, d2 / 2, d3 / 6, d4 / 24, d5 / 120]
    default: coeffs = [f0]
    }
    
    let series = Function { input in
        let x = input - centerX
        var sum = 0.0
        for i in stride(from: coeffs.count - 1, through: 0, by: -1) {
            sum = sum * x + coeffs[i]
        }
        return sum
    }
    return TaylorSeriesResult(series: series, coefficients: coeffs, centerX: centerX)
}

// Maintains original API for callers that only want the Function.
func generateTaylorSeries(for inputs: [GraphPoint], degree: Int, center: Double) async throws -> Function {
    let result = try await generateTaylorSeriesResult(for: inputs, degree: degree, center: center)
    return result.series
}

// Async version of generate taylor series
func generateTaylorSeriesDetached(for inputs: [GraphPoint], degree: Int, center: Double) async throws -> Function {
    try await Task.detached(priority: .userInitiated) {
        try await generateTaylorSeries(for: inputs, degree: degree, center: center)
    }.value
}

// Caching data
// The cached series is always sampled over a fixed ±80 domain (see
// computeTaylorData / ensureTaylorPoints), so the sampling window carries no
// information and must NOT be part of the key — otherwise the prewarmer and the
// foreground lookup, which derived the window from different domains, produced
// different keys and never shared a cache entry.
nonisolated struct PlotKey: Hashable, Equatable {
    let functionID: UUID
    let degree: Int
    let centerBucket: Double
    let refined: Bool
}

actor TaylorSeriesCache {
    static let shared = TaylorSeriesCache()
    
    private var seriesCache: [PlotKey: CachedSeries] = [:]
    private var pointsLRU: [PlotKey] = []
    // Entries are now ~6 coefficients each, so we can hold far more cheaply.
    private let cacheCapacity = 20000

    // Foreground hit/miss stats (only computeTaylorData records these; the
    // prewarmer uses `contains` so its existence checks don't skew the ratio).
    private(set) var hits = 0
    private(set) var misses = 0

    var count: Int { seriesCache.count }

    struct Stats: Sendable { let hits: Int; let misses: Int; let entries: Int }
    func stats() -> Stats { Stats(hits: hits, misses: misses, entries: seriesCache.count) }
    func resetStats() { hits = 0; misses = 0 }

    /// Existence check that does NOT affect hit/miss stats (used by prewarming).
    func contains(_ key: PlotKey) -> Bool { seriesCache[key] != nil }

    /// Foreground lookup: records a hit or miss and refreshes LRU on hit.
    func getSeries(for key: PlotKey) -> CachedSeries? {
        if let v = seriesCache[key] {
            if let idx = pointsLRU.firstIndex(of: key) { pointsLRU.remove(at: idx) }
            pointsLRU.append(key)
            hits += 1
            return v
        }
        misses += 1
        return nil
    }

    func putSeries(_ data: CachedSeries, for key: PlotKey) {
        seriesCache[key] = data
        if let idx = pointsLRU.firstIndex(of: key) { pointsLRU.remove(at: idx) }
        pointsLRU.append(key)
        while pointsLRU.count > cacheCapacity {
            let oldest = pointsLRU.removeFirst()
            seriesCache.removeValue(forKey: oldest)
        }
    }
    
    private func keySummary(_ key: PlotKey) -> String {
        "func:\(key.functionID.uuidString.prefix(6)) deg:\(key.degree) c:\(String(format: "%.2f", key.centerBucket)) \(key.refined ? "R" : "C")"
    }
}

func bucket(_ value: Double, step: Double) -> Double {
    (value / step).rounded() * step
}

#Preview {
    HomeView()
}
