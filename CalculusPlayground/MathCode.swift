//
//  MathCode.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 23/12/25.
//

import Foundation

class GraphPoint: Identifiable {
    var id: UUID = UUID()
    var xh: Double
    var yv: Double
    
    init(xh: Double, yv: Double) {
        self.xh = xh
        self.yv = yv
    }
}

class Function: Identifiable, Hashable {
    var id: UUID = UUID()
    
    nonisolated let transform: (Double) -> Double
    
    init(transform: @escaping (Double) -> Double) {
        self.transform = transform
    }
    
    static let identity: Function = .init(transform: { $0 })
    static let sine: Function = .init(transform: { sin($0) })
    static let square: Function = .init(transform: { $0 * $0 })
    static let naturalLog: Function = .init(transform: { log($0) })
    static let inverse: Function = .init(transform: { 1 / $0 })
    static let exp: Function = .init(transform: { pow(2.71828, $0) })
    
    static let humpy: Function = .init { x in
        let x2 = x * x
        let x4 = x2 * x2
        let x6 = x4 * x2
        let x8 = x4 * x4
      
        let b8 = 1.0e-10
        let b6 = 1.2e-7
        let b4 = 3.0e-4
        let b2 = 0.002
        return b8 * x8 - b6 * x6 + b4 * x4 - b2 * x2
    }
    
    static func == (lhs: Function, rhs: Function) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum SeriesGenerationError: Error, LocalizedError {
    case insufficentData
    case invalidDegree
    case missingCenter
    case missingSymetricPoints
    case failedValueMap
    case failedDerivative(order: Int)
    
    var errorDescription: String? {
        switch self {
        case .insufficentData: return "Insufficient data to compute the requested Taylor series."
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

// Generates the Taylor series polynomial (as a Function) centered at `center`,
// and returns the coefficients (already factorial-normalized) and the centerX actually used.
func generateTaylorSeriesResult(for inputs: [GraphPoint], degree: Int, center: Double) async throws -> TaylorSeriesResult {
    guard !inputs.isEmpty else { throw SeriesGenerationError.insufficentData }
    guard (1...5).contains(degree) else { throw SeriesGenerationError.invalidDegree }
    
    let sortedData = inputs.sorted { $0.xh < $1.xh }
    
    let tol = 0.006
    func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= tol }
    func y(at targetX: Double) -> Double? {
        sortedData.first(where: { isClose($0.xh, targetX) })?.yv
    }
    
    guard let f0 = y(at: center) else { throw SeriesGenerationError.missingCenter }
    let centerX = (sortedData.first(where: { isClose($0.xh, center) })?.xh)!
    
    let positiveXs = sortedData.map { $0.xh }.filter { ($0 - centerX) > tol }
    let symmetricPositives = positiveXs.sorted().filter { xp in
        y(at: (2*centerX - xp)) != nil && y(at: xp) != nil
    }
    guard let firstPos = symmetricPositives.first else {
        throw SeriesGenerationError.missingSymetricPoints
    }
    let h = firstPos - centerX
    
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
struct PlotKey: Hashable, Equatable {
    let functionID: UUID
    let degree: Int
    let centerBucket: Double
    let xLowerBucket: Double
    let xUpperBucket: Double
    let refined: Bool
    
    static func == (lhs: PlotKey, rhs: PlotKey) -> Bool {
        lhs.functionID == rhs.functionID &&
        lhs.degree == rhs.degree &&
        lhs.centerBucket == rhs.centerBucket &&
        lhs.xLowerBucket == rhs.xLowerBucket &&
        lhs.xUpperBucket == rhs.xUpperBucket &&
        lhs.refined == rhs.refined
    }
}

actor TaylorCache {
    static let shared = TaylorCache()
    
    private var pointsCache: [PlotKey: [GraphPoint]] = [:]
    private var pointsLRU: [PlotKey] = []
    private let pointsCapacity = 800// tune this
    
    // New: full results cache
    private struct FullEntry {
        let points: [GraphPoint]
        let coefficients: [Double]
        let centerX: Double
    }
    private var fullCache: [PlotKey: FullEntry] = [:]
    private var fullLRU: [PlotKey] = []
    private let fullCapacity = 400 // tune separately if desired
    
    // Points cache API
    func getPoints(for key: PlotKey) -> [GraphPoint]? {
        if let v = pointsCache[key] {
            if let idx = pointsLRU.firstIndex(of: key) { pointsLRU.remove(at: idx) }
            pointsLRU.append(key)
            return v
        }
        return nil
    }
    
    func putPoints(_ pts: [GraphPoint], for key: PlotKey) {
        pointsCache[key] = pts
        if let idx = pointsLRU.firstIndex(of: key) { pointsLRU.remove(at: idx) }
        pointsLRU.append(key)
        while pointsLRU.count > pointsCapacity {
            let oldest = pointsLRU.removeFirst()
            pointsCache.removeValue(forKey: oldest)
        }
    }
    

    func getFull(for key: PlotKey) -> Helpers.TaylorComputationData? {
        if let v = fullCache[key] {
            if let idx = fullLRU.firstIndex(of: key) { fullLRU.remove(at: idx) }
            fullLRU.append(key)
            return Helpers.TaylorComputationData(points: v.points, coefficients: v.coefficients, centerX: v.centerX)
        }
        return nil
    }
     
    func putFull(_ data: Helpers.TaylorComputationData, for key: PlotKey) {
        let entry = FullEntry(points: data.points, coefficients: data.coefficients, centerX: data.centerX)
        fullCache[key] = entry
        if let idx = fullLRU.firstIndex(of: key) { fullLRU.remove(at: idx) }
        fullLRU.append(key)
        while fullLRU.count > fullCapacity {
            let oldest = fullLRU.removeFirst()
            fullCache.removeValue(forKey: oldest)
        }
    }
    
    private func keySummary(_ key: PlotKey) -> String {
        "func:\(key.functionID.uuidString.prefix(6)) deg:\(key.degree) c:\(String(format: "%.2f", key.centerBucket)) x:[\(String(format: "%.1f", key.xLowerBucket)),\(String(format: "%.1f", key.xUpperBucket))] \(key.refined ? "R" : "C")"
    }
}


func bucket(_ value: Double, step: Double) -> Double {
    (value / step).rounded() * step
}

