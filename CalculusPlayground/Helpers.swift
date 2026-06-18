//
//  Stuff.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 6/1/26.
//

import SwiftUI
import Charts

///A helper class that uses a shared singleton static member (Helpers.shared)
class Helpers {
    static let shared = Helpers()
    ///Gap between dots of the function and taylor series as well as the snap of the slider for center control for Taylor Series and Tangent
    let increment = 0.08
    
    let derivativeH = 0.08
    
    ///Number of seconds before graph updates
    let maxUpdateFrequency = 0.08
    
    ///Graph gradient
    let graphGradient = MeshGradient(
        width: 2,
        height: 2,
        points: [
            .init(x: 1, y: 1),
            .init(x: 0, y: 1),
            .init(x: 1, y: 0),
            .init(x: 0, y: 0)
        ],
        colors: [Color.yellow, Color.red, Color.mint, Color.yellow].map { $0.opacity(0.2) })
    
    let backgroundGradient = LinearGradient(colors: [Color.clear, Color.green, Color.blue].map { $0.opacity(0.2) }, startPoint: .top, endPoint: .bottom)
    
    func axisMarks(for scale: Double, position: AxisMarkPosition) -> AxisMarks<some AxisMark> {
        AxisMarks(position: position, values: .stride(by: max(1, scale / 4))) { value in
            AxisGridLine().foregroundStyle(.gray.opacity(0.4))
            AxisTick().foregroundStyle(.gray.opacity(0.4))
            AxisValueLabel() {
                if let x = value.as(Double.self) {
                    Text(x.formatted(.number.precision(.fractionLength(0))))
                }
            }
            .foregroundStyle(.secondary)
        }
    }
    /// Result of Taylor Series computation
    struct TaylorComputationData {
        let points: [GraphPoint]
        let coefficients: [Double]
        let centerX: Double
    }
    
    
    func makeScriptedString(_ x: String, script: String, exponent: Bool, scriptFirst: Bool = false) -> AttributedString {
        var first = AttributedString(x)
        var second = AttributedString(script)
        second.baselineOffset = exponent ? 4 : -4
        second.font = .caption
        scriptFirst ? second.append(first) : first.append(second)
        return scriptFirst ? second : first
    }
    
    ///Computes Taylor Series from dot data, or uses cache
    func computeTaylorData(functionID: UUID,
                           degree: Int,
                           center: Double,
                           domain: ClosedRange<Double>,
                           inputs: [GraphPoint]) async throws -> TaylorComputationData {
        let centerBucket = bucket(center, step: Helpers.shared.increment)

        let key = PlotKey(functionID: functionID,
                          degree: degree,
                          centerBucket: centerBucket,
                          refined: true)
        
        // On a hit we only stored the polynomial; sample display points now.
        if let cached = await TaylorSeriesCache.shared.getSeries(for: key) {
            return TaylorComputationData(points: sampleTaylorPoints(cached),
                                         coefficients: cached.coefficients,
                                         centerX: cached.centerX)
        }

        let seriesResult = try await generateTaylorSeriesResult(for: inputs, degree: degree, center: centerBucket)
        let cached = CachedSeries(coefficients: seriesResult.coefficients, centerX: seriesResult.centerX)
        await TaylorSeriesCache.shared.putSeries(cached, for: key)

        return TaylorComputationData(points: sampleTaylorPoints(cached),
                                     coefficients: cached.coefficients,
                                     centerX: cached.centerX)
    }
    
    ///Adds entry to cache if not already present there
    func ensureTaylorPoints(functionID: UUID,
                            degree: Int,
                            centerBucket: Double,
                            refinedDomain: ClosedRange<Double>,
                            inputs: [GraphPoint]) async {
        let key = PlotKey(functionID: functionID,
                          degree: degree,
                          centerBucket: centerBucket,
                          refined: true)
        
        if await TaylorSeriesCache.shared.contains(key) {
            return
        }
        guard let series = try? await generateTaylorSeriesResult(for: inputs, degree: degree, center: centerBucket) else {
            return
        }
        // Prewarming only computes & stores the polynomial — no point sampling.
        await TaylorSeriesCache.shared.putSeries(
            CachedSeries(coefficients: series.coefficients, centerX: series.centerX), for: key)
    }
    
    // MARK: - String/attributed formatting helpers
    /// Creates visually appealing superscript in UI
    func superscript(_ s: String, scale: CGFloat = 0.7, raise: CGFloat = 6) -> AttributedString {
        var a = AttributedString(s)
        a.font = .system(size: UIFont.preferredFont(forTextStyle: .body).pointSize * scale, weight: .regular, design: .monospaced)
        a.baselineOffset = raise
        return a
    }
    /// Creates a string representation of a double with only fractionDigits digits
    func fixedNumberString(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
    
    ///Creates a string representation of a polynomial using a [Double] of coefficients and center using a (x-c)^n + form
    func attributedPolynomial(coeffs: [Double], center: Double) -> AttributedString {
        guard !coeffs.isEmpty else { return AttributedString("f(x) = 0") }
        let tol = 1e-10
        
        let roundedCenter = (center * 10).rounded() / 10.0
        
        var result = AttributedString("f(x) = ")
        var firstTerm = true
        
        func appendSign(_ isNegative: Bool) {
            if firstTerm {
                if isNegative { result.append(AttributedString("− ")) }
            } else {
                result.append(AttributedString(isNegative ? " − " : " + "))
            }
        }
        
        for (i, a) in coeffs.enumerated() {
            if abs(a) < tol { continue }
            let isNeg = a < 0
            let absA = abs(a)
            appendSign(isNeg)
            
            var coefAttr = AttributedString()
            var usedImplicitOne = false
            
            if i == 0 {
                coefAttr = AttributedString(fixedNumberString(absA, fractionDigits: 2))
            } else {
                if absA.isApproximately(1.0, tol: 1e-12) {
                    usedImplicitOne = true
                } else {
                    coefAttr = AttributedString(fixedNumberString(absA, fractionDigits: 2) + " ")
                }
            }
            
            var xPart = AttributedString()
            if i > 0 {
                if roundedCenter == 0 {
                    xPart.append(AttributedString("x"))
                } else {
                    let cStr = fixedNumberString(roundedCenter, fractionDigits: 1)
                    xPart.append(AttributedString("(x − \(cStr))"))
                }
                if i >= 2 {
                    xPart.append(superscript(String(i)))
                }
            }
            
            if i == 0 {
                result.append(coefAttr)
            } else {
                if !usedImplicitOne { result.append(coefAttr) }
                result.append(xPart)
            }
            
            firstTerm = false
        }
        
        if firstTerm {
            return AttributedString("p(x) = 0")
        }
        return result
    }
}

extension Double {
    func isApproximately(_ other: Double, tol: Double) -> Bool {
        abs(self - other) <= tol
    }
}

extension CGSize {
    static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }
}
