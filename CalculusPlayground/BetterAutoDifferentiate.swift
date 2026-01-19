//
//  BetterAutoDifferentiate.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 19/1/26.
//

import Foundation

// Fundamental components making up a function. indirect just means the enum can be recursive.
indirect enum Component: Equatable {
    case sum(_ a1: Component, _ a2: Component)
    case product(_ f1: Component, _ f2: Component)
    case power(_ b: Component, _ e: Component)
    case compose(_ g: Component, _ f: Component)
    case variable
    case constant(_ value: Double)
}

struct Expression: Identifiable, Hashable {
    let id: UUID = UUID()
    
    let mathText: String?
    let transform: (Double) -> Double
    
    
    // This is the thing that is used when differentiating. Its basically a combonation of components that representa a function.
    var directory: Component
    
    init(mathText: String? = nil, directory: Component, transform: @escaping (Double) -> Double) {
        self.mathText = mathText
        self.transform = transform
        self.directory = directory
    }
    
    // init via Composition
    init(mathText: String?, g: Expression, f: Expression) {
        self.mathText = mathText
        
        self.transform = { x in
            let insideValue = g.transform(x)
            return f.transform(insideValue)
        }
        
        self.directory = Component.compose(g.directory, f.directory)
    }
    
    // init via Sum
    init(mathText: String?, a1: Expression, a2: Expression) {
        self.mathText = mathText
        
        self.transform = { x in
            return a1.transform(x) + a2.transform(x)
        }
        
        self.directory = Component.sum(a1.directory, a2.directory)
    }
    
    // init via Product
    init(mathText: String?, f1: Expression, f2: Expression) {
        self.mathText = mathText
        
        self.transform = { x in
            return f1.transform(x) * f2.transform(x)
        }
        
        self.directory = Component.product(f1.directory, f2.directory)
    }
 
    // init via power
    init(mathText: String?, b: Expression, e: Expression) {
        self.mathText = mathText
        
        self.transform = { x in
            return pow(b.transform(x), e.transform(x))
        }
        
        self.directory = Component.power(e.directory, b.directory)
    }
    
    static func == (lhs: Expression, rhs: Expression) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}


// Differentiates a fucntion directory
func differentiate(_ directory: Component) -> Component {
    switch directory {
    case .variable:
        return Component.constant(1)
        
    case .constant(let c):
        return Component.constant(0)
        
    case .product(let f1, let f2):
        return Component.sum(
            .product(f1, differentiate(f2)),
            .product(f2, differentiate(f1))
        )
    case .compose(let g, let f):
        return Component.product(
            differentiate(g),
            .compose(differentiate(f), g)
        )
        
    case .sum(let a1, let a2):
        return Component.sum(differentiate(a1), differentiate(a2))
        
    case .power(let b, let e):
        // I haven't done this yet. You need to use the rule for f(x)^g(x) which is super long. It basically combines the product rule and the ruel for exponentials, so it works for any expression on the base or exponent. You can google it. Its really long, so its just a bit of work to code at the moment.
        
    default:
        return Component.constant(67)
        
    }
}

