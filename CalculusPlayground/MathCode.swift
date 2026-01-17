//
//  MathCode.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 23/12/25.
//

import Foundation
import SwiftUI

///Represents a point on a graph, with xh and yv as x and y
class GraphPoint: Identifiable {
    var id: UUID = UUID()
    ///x
    var xh: Double
    ///y
    var yv: Double
    
    init(xh: Double, yv: Double) {
        self.xh = xh
        self.yv = yv
    }
}
///Represents a mathematical function
class Function: Identifiable, Hashable {
    //To be expanded upon
    
    nonisolated let id: UUID = UUID()
    
    ///This gives a view that looks like the function, like Text("x") for identity
    nonisolated let mathText: String?
    nonisolated let transform: (Double) -> Double
    init(transform: @escaping (Double) -> Double, text: String? = nil) {
        self.transform = transform
        self.mathText = text
    }
    
    static let identity: Function = .init(transform: { $0 }, text: "x")
    static let sine: Function = .init(transform: { sin($0) }, text: "sin(x)")
    static let square: Function = .init(transform: { $0 * $0 }, text: "x^2")
    static let naturalLog: Function = .init(transform: { log($0) }, text: "ln(x)")
    static let inverse: Function = .init(transform: { 1 / $0 }, text: "1/x")
    static let exp: Function = .init(transform: { pow(2.71828, $0) }, text: "e^x")
    
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

enum integralError: Error, LocalizedError {
    case invalidSum
}


func generateIntegral(for inputs: [GraphPoint], range: ClosedRange<Double>) async throws -> (Double, [GraphPoint]) {
    print("\n INTEGRAl: ")
    var filtered = inputs.filter({ $0.xh > range.lowerBound && $0.xh < range.upperBound})

    _ = filtered.popLast()
    
    
    // prevents index out of range error
    guard filtered.count > 2 else {
        return (0, [])
    }
    
    
    let h = filtered[1].xh - filtered[0].xh
    print("H: \(h)")
    
    var sum = 0.0
    var rectangles = [] as [GraphPoint]
    for i in filtered {
        
        sum += (i.yv * h)
        rectangles.append(GraphPoint(xh: i.xh + h * 1/300, yv: i.yv))
        rectangles.append(GraphPoint(xh: i.xh + h * 299/300, yv: i.yv))
        
    }
    
    guard !sum.isNaN else {
        throw integralError.invalidSum
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
    
    let sortedData = inputs.sorted { $0.xh < $1.xh }
    
    let tol = 11.0/20.0 * Helpers.shared.increment
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
nonisolated struct PlotKey: Hashable, Equatable {
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

actor TaylorSeriesCache {
    static let shared = TaylorSeriesCache()
    
    private var pointsCache: [PlotKey: Helpers.TaylorComputationData] = [:]
    private var pointsLRU: [PlotKey] = []
    private let cacheCapacity = 1600
    
    func getPoints(for key: PlotKey) -> Helpers.TaylorComputationData? {
        if let v = pointsCache[key] {
            if let idx = pointsLRU.firstIndex(of: key) { pointsLRU.remove(at: idx) }
            pointsLRU.append(key)
            return v
        }
        return nil
    }
    
    func putPoints(_ data: Helpers.TaylorComputationData, for key: PlotKey) {
        pointsCache[key] = data
        if let idx = pointsLRU.firstIndex(of: key) { pointsLRU.remove(at: idx) }
        pointsLRU.append(key)
        while pointsLRU.count > cacheCapacity {
            let oldest = pointsLRU.removeFirst()
            pointsCache.removeValue(forKey: oldest)
        }
    }
    
    private func keySummary(_ key: PlotKey) -> String {
        "func:\(key.functionID.uuidString.prefix(6)) deg:\(key.degree) c:\(String(format: "%.2f", key.centerBucket)) x:[\(String(format: "%.1f", key.xLowerBucket)),\(String(format: "%.1f", key.xUpperBucket))] \(key.refined ? "R" : "C")"
    }
}

func bucket(_ value: Double, step: Double) -> Double {
    (value / step).rounded() * step
}
