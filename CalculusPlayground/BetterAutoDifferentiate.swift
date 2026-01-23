//
//  BetterAutoDifferentiate.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 19/1/26.
//

import Foundation
import SwiftUI

// Fundamental components making up a function. indirect just means the enum can be recursive.
indirect enum Component: Equatable {
    case sum(_ a1: Component, _ a2: Component)
    case product(_ f1: Component, _ f2: Component)
    case power(_ b: Component, _ e: Component)
    case variable
    case constant(_ value: Double)
    case ln(_ arg: Component) // <-- NEW: natural logarithm
    case sin(_ arg: Component)
    case cos(_ arg: Component)
}

struct Expression: Identifiable, Hashable {
    let id: UUID = UUID()
    
    let mathText: String?
    let transform: (Double) -> Double
    
    // This is the thing that is used when differentiating. Its basically a combonation of components that representa a function.
    var directory: Component
    
    init(_ mathText: String? = nil, directory: Component, transform: @escaping (Double) -> Double) {
        self.mathText = mathText
        self.transform = transform
        self.directory = directory
    }
    
    
    // init via Sum
    init(_ mathText: String?, a1: Expression, a2: Expression) {
        self.mathText = mathText
        
        self.transform = { x in
            return a1.transform(x) + a2.transform(x)
        }
        
        self.directory = Component.sum(a1.directory, a2.directory)
    }
    
    // init via Product
    init(_ mathText: String?, f1: Expression, f2: Expression) {
        self.mathText = mathText
        
        self.transform = { x in
            return f1.transform(x) * f2.transform(x)
        }
        
        self.directory = Component.product(f1.directory, f2.directory)
    }
 
    // init via power
    init(_ mathText: String?, b: Expression, e: Expression) {
        self.mathText = mathText
        
        self.transform = { x in
            return pow(b.transform(x), e.transform(x))
        }
        
        self.directory = Component.power(e.directory, b.directory)
    }
    
    // init from directory
    init(_ mathText: String?, directory: Component) {
        self.mathText = mathText
        self.directory = directory
        
        // Recursively derives a transform from a directory.
        func evaluator(for component: Component) -> (Double) -> Double {
            switch component {
            case .variable:
                return { x in x }
            case .constant(let value):
                return { _ in value }
            case .sum(let a1, let a2):
                let f1 = evaluator(for: a1)
                let f2 = evaluator(for: a2)
                return { x in f1(x) + f2(x) }
            case .product(let f1, let f2):
                let f1 = evaluator(for: f1)
                let f2 = evaluator(for: f2)
                return { x in f1(x) * f2(x) }
            case .power(let b, let e):
                let base = evaluator(for: b)
                let exp = evaluator(for: e)
                return { x in pow(base(x), exp(x)) }
            case .ln(let arg):
                let evalArg = evaluator(for: arg)
                return { x in log(evalArg(x)) }
            case .sin(let arg):
                let evalArg = evaluator(for: arg)
                return { x in sin(evalArg(x)) }
            case .cos(let arg):
                let evalArg = evaluator(for: arg)
                return { x in cos(evalArg(x)) }
            }
        }
        
        self.transform = evaluator(for: directory)
    }
    
    static func == (lhs: Expression, rhs: Expression) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}


func textify(_ component: Component) -> String {
    switch component {
    case .variable:
        return "x"
    case .constant(let c):
        return "\(c)"
    case .sum(let a1, let a2):
        return "(\(textify(a1)) + \(textify(a2)))"
    case .product(let f1, let f2):
        return "(\(textify(f1)) * \(textify(f2)))"
    case .power(let b, let e):
        return "\(textify(b))^\(textify(e))"
    case .ln(let arg):
        return "ln(\(textify(arg)))"
    case .sin(let arg):
        return "sin(\(textify(arg)))"
    case .cos(let arg):
        return "sin(\(textify(arg)))"
    }
}

// Differentiates a fucntion directory
func differentiate(_ directory: Component) -> Component {
    switch directory {
    case .variable:
        return Component.constant(1)
        
    case .constant(_):
        return Component.constant(0)
        
    case .product(let f1, let f2):
        return Component.sum(
            .product(f1, differentiate(f2)),
            .product(f2, differentiate(f1))
        )
        
    case .sum(let a1, let a2):
        return Component.sum(differentiate(a1), differentiate(a2))
        
    case .power(let b, let e):
        // Chain rule for f(x)^g(x):
        // d/dx [b^e] = b^e * (e * b'/b + e' * ln(b))
        // where b = f(x), e = g(x)
        let bPrime = differentiate(b)
        let ePrime = differentiate(e)
        let term1 = Component.product(e, Component.product(bPrime, Component.power(b, Component.constant(-1))))
        let term2 = Component.product(ePrime, Component.ln(b))
        let sum = Component.sum(term1, term2)
        return Component.product(Component.power(b, e), sum)
    case .ln(let arg):
        // d/dx ln(f(x)) = f'(x)/f(x)
        let argPrime = differentiate(arg)
        return Component.product(argPrime, Component.power(arg, Component.constant(-1)))
        
    case .sin(let arg):
        // d/dx ln(f(x)) = f'(x)/f(x)
        let argPrime = differentiate(arg)
        return Component.product(argPrime, .cos(arg))
    case .cos(let arg):
        // d/dx ln(f(x)) = f'(x)/f(x)
        let argPrime = differentiate(arg)
        return Component.product(argPrime, .product(.constant(-1), .sin(arg)))
    }
}

struct BetterAutoDifferentiateDemoView: View {
    @State private var xValue: Double = 2.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BetterAutoDifferentiate Demo")
                .font(.title).bold()
            
            // Let's try f(x) = x^x
            let powx = Component.product(.sin(.variable), .constant(2))
            
            
            let expr = Expression("f(x)", directory: powx)
            let derivativeComponent = differentiate(expr.directory)
            let derivativeExpr = Expression("f'(x)", directory: derivativeComponent)
            
            Group {
                Text("Expression: f(x) = \(textify(expr.directory))")
                Text("Derivative: f'(x) = \(textify(derivativeComponent))")
                HStack {
                    Text("x =")
                    Slider(value: $xValue, in: 0.01...10, step: 0.01)
                    Text(String(format: "%.2f", xValue))
                }
                Text("f(\(String(format: "%.2f", xValue))) = \(expr.transform(xValue))")
                Text("f'(\(String(format: "%.2f", xValue))) = \(derivativeExpr.transform(xValue))")
            }
            .font(.system(.body, design: .monospaced))
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    BetterAutoDifferentiateDemoView()
}
