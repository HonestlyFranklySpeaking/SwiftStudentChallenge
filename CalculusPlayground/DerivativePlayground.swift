//
//  DerivativePlayground.swift
//  CalculusPlaygroundsApplet
//
//  Created by Milo Ullman on 18/12/25.
//

import SwiftUI
import Charts


struct DerivativePlayground: View {
    @State var xDomain: ClosedRange<Int> = -30...30
    @State var xDomainDouble: ClosedRange<Double> = -30...30
    @State var function: Function = .naturalLog
    @State var functionPoints: [GraphPoint] = []
    @State var graphPoints: [GraphPoint] = []
    init() {
        updatePoints()
    }
    func updatePoints() {
        points = []
        for x in xDomain {
            let doubleX = Double(x)
            let doubleY = function.transform(doubleX)
            if doubleY.isNormal {
                functionPoints.append(GraphPoint(xh: doubleX, yv: doubleY))
            }

                let derivativePoint = try? calculateDerivative(function: function, at: doubleX)
            if let dPoint = derivativePoint {
                graphPoints.append(GraphPoint(xh: doubleX, yv: dPoint))

        }
    }
    var body: some View {
        MathGraph(xDomain: $xDomainDouble, inputPoints: $points, )
    }
}





#Preview {
    DerivativePlayground()
}
