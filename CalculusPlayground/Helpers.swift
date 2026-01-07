//
//  Stuff.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 6/1/26.
//

import SwiftUI
import Charts

class Helpers {
    static let shared = Helpers()
    
    let gradient = MeshGradient(
        width: 2,
        height: 2,
        points: [
            .init(x: 1, y: 1),
            .init(x: 0, y: 1),
            .init(x: 1, y: 0),
            .init(x: 0, y: 0)
        ],
        colors: [Color.yellow, Color.red, Color.mint, Color.yellow].map { $0.opacity(0.2) })
    
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
    
    // MARK: - Taylor plotting helper
    
    func computeTaylorPoints(functionID: UUID,
                             degree: Int,
                             center: Double,
                             domain: ClosedRange<Double>,
                             inputs: [GraphPoint]) async -> Result<[GraphPoint], Error> {
        let centerBucket = bucket(center, step: 0.2)
        let xLowerBucket = bucket(domain.lowerBound, step: 0.5)
        let xUpperBucket = bucket(domain.upperBound, step: 0.5)
        
        let key = PlotKey(functionID: functionID,
                          degree: degree,
                          centerBucket: centerBucket,
                          xLowerBucket: xLowerBucket,
                          xUpperBucket: xUpperBucket,
                          refined: true)
        
        if let cached = await TaylorCache.shared.getPoints(for: key) {
            print("CACHE USED for center=\(centerBucket) count:\(cached.count)")
            return .success(cached)
        } else {
            print("MISS for center=\(centerBucket). Computing…")
        }
        
        do {
            let series = try await generateTaylorSeries(for: inputs, degree: degree, center: centerBucket)
            let start: Double = -80.0
            let end: Double = 80.0
            let step: Double = (end - start) / 800
            let xs = Array(stride(from: start, through: end, by: step))
            let points = xs.map { x in GraphPoint(xh: x, yv: series.transform(x)) }
            
            await TaylorCache.shared.putPoints(points, for: key)
            print("Successfully computed points for center=\(centerBucket)  count=\(points.count); appended to cache.")
            return .success(points)
        } catch {
            print("[Helpers.computeTaylorPoints] ERROR: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // MARK: - Prewarm helper
    
    // Ensures the Taylor points for a given function/degree/center bucket exist in cache
    // using a refined sampling domain. No-op if already cached.
    func ensureTaylorPoints(functionID: UUID,
                            degree: Int,
                            centerBucket: Double,
                            refinedDomain: ClosedRange<Double>,
                            inputs: [GraphPoint]) async {
        let key = PlotKey(functionID: functionID,
                          degree: degree,
                          centerBucket: centerBucket,
                          xLowerBucket: bucket(refinedDomain.lowerBound, step: 0.5),
                          xUpperBucket: bucket(refinedDomain.upperBound, step: 0.5),
                          refined: true)
        if let _ = await TaylorCache.shared.getPoints(for: key) {
            return
        }
        guard let series = try? await generateTaylorSeries(for: inputs, degree: degree, center: centerBucket) else {
            return
        }
        let start = refinedDomain.lowerBound
        let end = refinedDomain.upperBound
        let step = (end - start) / 800
        let xs = Array(stride(from: start, through: end, by: step))
        let pts = xs.map { x in GraphPoint(xh: x, yv: series.transform(x)) }
        await TaylorCache.shared.putPoints(pts, for: key)
    }
}

