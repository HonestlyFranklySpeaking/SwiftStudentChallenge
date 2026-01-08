//
//  MathGraph.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 8/1/26.
//

import SwiftUI
import Charts

struct MathGraph: View {
    @State private var graphScale: Double = 30
    
    @Binding var xDomain: ClosedRange<Double>
    @State private var yDomain: ClosedRange<Double> = -30...30
    
    @Binding var inputPoints: [GraphPoint]
    
    @Binding var taylorExpansionPoints: [GraphPoint]
    
    
    @State private var pinchScale: CGFloat = 1.0
    @State private var pinchBaseXDomain: ClosedRange<Double> = -30...30
    @State private var pinchBaseYDomain: ClosedRange<Double> = -30...30
    
    @State private var lastDragTranslation: CGSize = .zero
    
    
    private func invertedScale(from sliderValue: Double) -> Double {
        let clamped = max(5, min(100, sliderValue))
        return 105 - clamped // 5 -> 100, 100 -> 5
    }
    
    var body: some View {
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
        }                .frame(height: 340)
        .padding(.horizontal, 8)
        .gesture(dragGesture)
        .gesture(magnificationGesture)
        .task {
            let half = invertedScale(from: graphScale)
            xDomain = (-half)...(half)
            yDomain = (-half)...(half)
            pinchBaseXDomain = xDomain
            pinchBaseYDomain = yDomain
        }
        
    }
    
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
    
}

