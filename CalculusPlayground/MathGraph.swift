//
//  MathGraph.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 8/1/26.
//

import SwiftUI
import Charts

///Represents a set of points, with associated label and type etc.
struct Series: Identifiable {
    enum PlotType {
        case area
        case line
    }
    
    var id = UUID()
    
    var points: [GraphPoint]
    
    var label: String
    
    var plottype: PlotType = .line
}

struct MathGraph: View {
    
    var graphHeight: CGFloat = 340
    
    ///The actual scale for the graph
    @State private var graphScale: Double = 30
    
    @State var visibility = [true, false, false]
    
    ///Represents graphScale, xDomain, yDomain, pinchScale, pinchBaseXDomain, and pinchBaseYDomain default values in that order
    private let zoomDefaults: (Double, ClosedRange<Double>, ClosedRange<Double>, CGFloat, ClosedRange<Double>, ClosedRange<Double>) = (30, -30...30, -30...30, 1.0, -30...30, -30...30)
    
    @State private var xDomain: ClosedRange<Double> = -30...30
    @State private var yDomain: ClosedRange<Double> = -30...30
    
    var serieses: [Series]
    
    @State private var pinchScale: CGFloat = 1.0
    
    //These two represent the domains after last motion, as a basis for the next moment. It is updated after the end of every movement, rather than xDomain and yDomain, which are updated instantly.
    @State private var pinchBaseXDomain: ClosedRange<Double> = -30...30
    @State private var pinchBaseYDomain: ClosedRange<Double> = -30...30
    
    @State private var lastDragTranslation: CGSize = .zero
    
    // Master palette of styles for all known labels using a concrete ShapeStyle (LinearGradient)
    private var colorKey: [String: LinearGradient] {
        [
            "Function": LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing),
            "Derivative": LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing),
            "Second Derivative": LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing),
            "Tangent Line": LinearGradient(colors: [.mint, .teal], startPoint: .leading, endPoint: .trailing),
            "Taylor Series": LinearGradient(colors: [.brown, .indigo], startPoint: .leading, endPoint: .trailing), 
            "Riemann Sum": LinearGradient(colors: [.red.opacity(0.6), .orange.opacity(0.6)], startPoint: .trailing, endPoint: .leading),
            "Integral": LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing),
            "Second Integral": LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        ]
    }
    
    // Filter colorKey down to only the labels that are currently plotted.
    private var currentMappings: [String: LinearGradient] {
        let activeLabels = Set(serieses.map { $0.label })
        return colorKey.filter { activeLabels.contains($0.key) }
    }
    
    /// Returns 105 - clamped x
    private func invertedScale(from sliderValue: Double) -> Double {
        let clamped = max(5, min(100, sliderValue))
        return 105 - clamped
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            chartView
                .chartForegroundStyleScale(mapping: { label in
                    currentMappings[label] ?? LinearGradient(colors: [.white, .white], startPoint: .leading, endPoint: .trailing)
                })
                .chartLegend(position: .bottom, alignment: .center, spacing: 8)
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
                .frame(height: graphHeight)
                .gesture(dragGesture)
                .gesture(magnificationGesture)

            ZStack(alignment: .center) {
                Circle()
                    .frame(width: 30, height: 30, alignment: .center)
                    .foregroundStyle(.clear)
                    .glassEffect()
                
                Button {
                    (graphScale, xDomain, yDomain, pinchScale, pinchBaseXDomain, pinchBaseYDomain) = zoomDefaults
                    defaultStartupTask()
                } label: {
                    Image(systemName: "house")
                }
            }
            .padding()

        }
        .padding(.horizontal, 8)
        .task {
            defaultStartupTask()
        }
    }
    
    // Extracted chart content to reduce type-checking load
    private var chartView: some View {
        Chart {
            // Axes
            RuleMark(x: .value("Origin X", 0.0))
                .foregroundStyle(Color.gray.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
            RuleMark(y: .value("Origin Y", 0.0))
                .foregroundStyle(Color.gray.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
            
            // Series lines
            ForEach(serieses) { series in
                ForEach(series.points) { point in
                    if series.plottype == .area {
                        AreaMark(
                            x: .value("X", point.xh),
                            y: .value("Y", point.yv),
                            series: .value("Line", series.label)
                        )
                        .interpolationMethod(.linear)
                    }
                    
                    else if series.plottype == .line {
                        LineMark(
                            x: .value("X", point.xh),
                            y: .value("Y", point.yv),
                            series: .value("Line", series.label)
                        )
                        .interpolationMethod(.linear)
                    }
                }
                .foregroundStyle(by: .value("Line", series.label))
            }
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
    ///Task assigned to rescale graph
    func defaultStartupTask() {
        let half = invertedScale(from: graphScale)
        xDomain = (-half)...(half)
        yDomain = (-half)...(half)
        pinchBaseXDomain = xDomain
        pinchBaseYDomain = yDomain
    }
}

#Preview {
    MathGraph(serieses: [])
}
