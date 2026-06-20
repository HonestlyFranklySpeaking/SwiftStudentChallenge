//
//  BetterAutoDifferentiate.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 19/1/26.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// Fundamental components making up a function. indirect just means the enum can be recursive.
// Codable so a Component can ride along as a drag-and-drop payload (see Transferable
// conformance in FunctionInputField.swift).
nonisolated indirect enum Component: Equatable, Codable {
    case sum(_ a1: Component, _ a2: Component)
    case product(_ f1: Component, _ f2: Component)
    case power(_ b: Component, _ e: Component)
    case variable
    case constant(_ value: Double)
    case ln(_ arg: Component) // <-- NEW: natural logarithm
    case sin(_ arg: Component)
    case cos(_ arg: Component)
    case hole // an empty slot waiting to be filled by the editor
    case difference(_ a1: Component, _ a2: Component)
    case quotient(_ a1: Component, _ a2: Component)
}

extension Component {
    /// Walk to the node addressed by `path` (a list of child indices from the
    /// root) and return a new tree with that node replaced by `new`. An empty
    /// path replaces this node itself. Out-of-range indices are no-ops.
    ///
    /// Child indexing matches how `Tile` lays children out:
    ///  • sum/product: 0 = left, 1 = right
    ///  • power: 0 = base, 1 = exponent
    ///  • ln/sin/cos: 0 = argument
    func replacing(at path: ArraySlice<Int>, with new: Component) -> Component {
        guard let idx = path.first else { return new }
        let rest = path.dropFirst()
        switch self {
        case .sum(let a, let b):
            return idx == 0 ? .sum(a.replacing(at: rest, with: new), b)
                            : .sum(a, b.replacing(at: rest, with: new))
        case .difference(let a, let b):
            return idx == 0 ? .difference(a.replacing(at: rest, with: new), b)
            : .difference(a, b.replacing(at: rest, with: new))
        case .product(let a, let b):
            return idx == 0 ? .product(a.replacing(at: rest, with: new), b)
                            : .product(a, b.replacing(at: rest, with: new))
        case .quotient(let a, let b):
            return idx == 0 ? .quotient(a.replacing(at: rest, with: new), b)
                            : .quotient(a, b.replacing(at: rest, with: new))
        case .power(let base, let e):
            return idx == 0 ? .power(base.replacing(at: rest, with: new), e)
                            : .power(base, e.replacing(at: rest, with: new))
        case .ln(let arg):  return idx == 0 ? .ln(arg.replacing(at: rest, with: new))  : self
        case .sin(let arg): return idx == 0 ? .sin(arg.replacing(at: rest, with: new)) : self
        case .cos(let arg): return idx == 0 ? .cos(arg.replacing(at: rest, with: new)) : self
        case .variable, .constant, .hole:
            return self // leaves have no children
        }
    }

    func replacing(at path: [Int], with new: Component) -> Component {
        replacing(at: path[...], with: new)
    }

    /// True if this tree (or any sub-tree) still contains an unfilled slot.
    var hasHole: Bool {
        switch self {
        case .hole: return true
        case .variable, .constant: return false
        case .ln(let a), .sin(let a), .cos(let a): return a.hasHole
        case .sum(let a, let b), .product(let a, let b), .power(let a, let b), .difference(let a, let b), .quotient(let a, let b):
            return a.hasHole || b.hasHole
        }
    }
}

// Lets a Component ride along as a drag-and-drop payload. Declared in the same
// file as the type so its (auto-derived) Sendable conformance is in scope.
extension UTType {
    /// Private type for in-app drags only — no Info.plist declaration required.
    nonisolated static let calculusComponent = UTType(exportedAs: "com.calculusplayground.component")
}

extension Component: Transferable {
    nonisolated static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .calculusComponent)
    }
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
        
        self.directory = Component.power(b.directory, e.directory)
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
            case .difference(let a, let b):
                let f1 = evaluator(for: a)
                let f2 = evaluator(for: b)
                return { x in f1(x) - f2(x) }
            case .product(let f1, let f2):
                let f1 = evaluator(for: f1)
                let f2 = evaluator(for: f2)
                return { x in f1(x) * f2(x) }
            case .quotient(let a, let b):
                let f1 = evaluator(for: a)
                let f2 = evaluator(for: b)
                return { x in f1(x) / f2(x) }
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
            case .hole:
                // An unfilled slot has no value; surfaces as NaN rather than crashing.
                return { _ in Double.nan }
            }
        }
        
        self.transform = evaluator(for: directory)
    }
    
    static func == (lhs: Expression, rhs: Expression) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}


/// Pretty-print a constant: integers drop the trailing `.0` (so we get
/// `2 / x` rather than `2.0 / x^1.0`); non-integers print as-is.
private func formatConstant(_ v: Double) -> String {
    if v.isFinite, v == v.rounded(), abs(v) < 1e15 { return String(Int(v)) }
    return "\(v)"
}

/// True for components that never need parentheses as an operand.
private func isAtom(_ c: Component) -> Bool {
    switch c {
    case .variable, .constant, .ln, .sin, .cos: return true   // functions self-bracket their args
    default: return false
    }
}

func textify(_ component: Component) -> String {
    // A power's base needs brackets unless it's atomic: (a+b)^2, but x^2.
    func base(_ c: Component) -> String { isAtom(c) ? textify(c) : "(\(textify(c)))" }
    // A multiplication operand only needs brackets when it's a sum.
    func factor(_ c: Component) -> String { if case .sum = c { return "(\(textify(c)))" }; return textify(c) }
    // A denominator needs brackets when it's a sum or a product.
    func denom(_ c: Component) -> String {
        switch c { case .sum, .product: return "(\(textify(c)))"; default: return textify(c) }
    }

    switch component {
    case .variable:
        return "x"
    case .constant(let c):
        return formatConstant(c)
    case .sum(let a1, let a2):
        return "\(textify(a1)) + \(textify(a2))"

    case .product:
        // Flatten, then split factors into a numerator and a denominator
        // (the latter built from factors with a negative exponent).
        var numerator: [Component] = []
        var denominator: [Component] = []
        for f in productFactors(component) {
            if case .power(let b, .constant(let n)) = f, n < 0 {
                denominator.append(n == -1 ? b : .power(b, .constant(-n)))
            } else {
                numerator.append(f)
            }
        }
        let numStr = numerator.isEmpty ? "1" : numerator.map(factor).joined(separator: " * ")
        if denominator.isEmpty { return numStr }
        let denStr = denominator.count == 1
            ? denom(denominator[0])
            : "(" + denominator.map(factor).joined(separator: " * ") + ")"
        return "\(numStr) / \(denStr)"

    case .power(let b, let e):
        // A lone negative power is a reciprocal: x^-1 -> 1 / x, x^-2 -> 1 / x^2.
        if case .constant(let n) = e, n < 0 {
            let d = n == -1 ? base(b) : "\(base(b))^\(formatConstant(-n))"
            return "1 / \(d)"
        }
        return "\(base(b))^\(factor(e))"

    case .ln(let arg):
        return "ln(\(textify(arg)))"
    case .sin(let arg):
        return "sin(\(textify(arg)))"
    case .cos(let arg):
        return "cos(\(textify(arg)))"
    case .hole:
        return "□"
    case .difference(let a, let b):
        return "\(textify(a)) + (-\(textify(b)))"
    case .quotient(let a, let b):
        return textify(simplify(.product(a, .power(b, .constant(-1)))))
    }
}

// Differentiates a fucntion directory
func differentiate(_ directory: Component) -> Component {
    let c = purgeDifferenceQuotients(directory)
    switch c {
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
    case .hole:
        // The derivative of an unknown is still unknown.
        return .hole
    case .difference(let a, let b):
        return .difference(differentiate(a), differentiate(b))
    case .quotient(let a, let b):
        return differentiate(.product(a, .power(b, .constant(-1))))
    }
    
    func purgeDifferenceQuotients(_ c: Component) -> Component {
        switch c {
        case .difference(let a, let b):
            return .sum(purgeDifferenceQuotients(a), .product(purgeDifferenceQuotients(b), .constant(-1)))
        case .quotient(let a, let b):
            return .product(purgeDifferenceQuotients(a), .power(purgeDifferenceQuotients(b), .constant(-1)))
        case .sin(let a):
            return .sin(purgeDifferenceQuotients(a))
        case .cos(let a):
            return .cos(purgeDifferenceQuotients(a))
        case .ln(let a):
            return .ln(purgeDifferenceQuotients(a))
        case .product(let a, let b):
            return .product(purgeDifferenceQuotients(a), purgeDifferenceQuotients(b))
        case .sum(let a, let b):
            return .sum(purgeDifferenceQuotients(a), purgeDifferenceQuotients(b))
        case .power(let a, let b):
            return .power(purgeDifferenceQuotients(a), purgeDifferenceQuotients(b))
        case .constant, .variable, .hole:
            return c
        }
    }
}

/// Snaps a Double to the nearest integer if it's within `epsilon`.
/// This is what turns `log(2.718) = 0.99989…` into `1`. It's a heuristic:
/// raise epsilon to catch more "intended" integers, lower it to avoid
/// corrupting genuine near-integer constants. Set epsilon to 0 to disable.
private func foldConstant(_ value: Double, epsilon: Double) -> Double {
    guard epsilon > 0, value.isFinite else { return value }
    let rounded = value.rounded()
    return abs(value - rounded) <= epsilon ? rounded : value
}

/// An order-insensitive, unambiguous string serialization of a Component.
/// Used as a grouping/sorting key during simplification so that structurally
/// identical sub-trees (e.g. the two `x`s in `x * x`) are recognised as equal
/// and ordered deterministically. Kept separate from `textify` so that how we
/// *canonicalize* never depends on how we *display*.
private func structureKey(_ c: Component) -> String {
    switch c {
    case .variable:                 return "x"
    case .constant(let v):          return "c(\(v))"
    case .sum(let a, let b):        return "S(\(structureKey(a)),\(structureKey(b)))"
    case .difference:               return structureKey(simplify(c))
    case .product(let a, let b):    return "P(\(structureKey(a)),\(structureKey(b)))"
    case .quotient:                 return structureKey(simplify(c))
    case .power(let b, let e):      return "W(\(structureKey(b)),\(structureKey(e)))"
    case .ln(let a):                return "L(\(structureKey(a)))"
    case .sin(let a):               return "N(\(structureKey(a)))"
    case .cos(let a):               return "O(\(structureKey(a)))"
    case .hole:                     return "H"
    }
}

/// Flatten a (possibly nested) product into a flat list of factors.
/// `(a * b) * c` and `a * (b * c)` both yield `[a, b, c]`.
private func productFactors(_ c: Component) -> [Component] {
    if case .product(let a, let b) = c { return productFactors(a) + productFactors(b) }
    return [c]
}

/// Flatten a (possibly nested) sum into a flat list of terms.
private func sumTerms(_ c: Component) -> [Component] {
    if case .sum(let a, let b) = c { return sumTerms(a) + sumTerms(b) }
    return [c]
}

/// View any factor as `base ^ exponent`. A bare `f` is treated as `f ^ 1`,
/// which lets us combine `x` with `x^-1` by adding exponents.
private func asPower(_ c: Component) -> (base: Component, exp: Component) {
    if case .power(let b, let e) = c { return (b, e) }
    return (c, .constant(1))
}
/// Algebraically simplifies a Component to a canonical form.
///
/// Beyond local identities (`*1`, `+0`, `^1`, `*0 -> 0`, `^0 -> 1`) and
/// constant folding (`ln(2.718) -> 1`, `2 * 3 -> 6`), it canonicalizes whole
/// products and sums:
///  • products are flattened, then same-base factors are merged by adding
///    exponents — so `x * x^-1 -> 1`, `x^2 * x^-1 -> x`, and numeric factors
///    collapse into a single leading coefficient.
///  • sums are flattened, then like terms are collected by adding coefficients
///    — so `2*f + 3*f -> 5*f` and `f + f -> 2*f`.
///
/// It repeats until the tree stops changing, so cascading rewrites resolve
/// fully (capped to guarantee termination even if a rule fails to be idempotent).
///
/// - Parameter epsilon: tolerance for snapping folded constants to integers.
///   Defaults to 1e-3 so approximations of e (2.718) collapse cleanly. Pass 0
///   for exact folding only.
func simplify(_ component: Component, epsilon: Double = 1e-3) -> Component {
    func fold(_ v: Double) -> Double { foldConstant(v, epsilon: epsilon) }

    // f^0 = 1, f^1 = f, 1^f = 1, fold constant powers. base/exp are pre-simplified.
    func simplifyPower(_ base: Component, _ exp: Component) -> Component {
        switch (base, exp) {
        case (_, .constant(0)):                       return .constant(1)
        case (_, .constant(1)):                       return base
        case (.constant(1), _):                       return .constant(1)
        case (.constant(let bv), .constant(let ev)):  return .constant(fold(pow(bv, ev)))
        case (.power(let b, let e), let x):           return .power(b, .product(e, x))
        default:                                      return .power(base, exp)
        }
    }

    // Rebuild a left-associated product from an ordered factor list.
    func makeProduct(_ factors: [Component]) -> Component {
        guard let first = factors.first else { return .constant(1) }
        return factors.dropFirst().reduce(first) { .product($0, $1) }
    }

    // Flatten a product, fold its numeric coefficient, and merge same-base factors.
    func simplifyProduct(_ c: Component) -> Component {
        var coeff = 1.0
        // Ordered groups so output is deterministic; each holds a base + its exponents.
        var groups: [(base: Component, key: String, exps: [Component])] = []

        for raw in productFactors(c) {
            // simp(raw) may itself be a product (e.g. a folded sum), so re-flatten.
            for f in productFactors(simp(raw)) {
                if case .constant(let v) = f { coeff *= v; continue }
                let (base, exp) = asPower(f)
                let key = structureKey(base)
                if let i = groups.firstIndex(where: { $0.key == key }) {
                    groups[i].exps.append(exp)
                } else {
                    groups.append((base, key, [exp]))
                }
            }
        }

        coeff = fold(coeff)
        if coeff == 0 { return .constant(0) }

        var built: [Component] = []
        for g in groups {
            let exponent = simp(makeSum(g.exps))      // add the collected exponents
            let pw = simplifyPower(simp(g.base), exponent)
            if case .constant(1) = pw { continue }    // base^0 etc. drops out
            built.append(pw)
        }
        built.sort { structureKey($0) < structureKey($1) }

        if built.isEmpty { return .constant(coeff) }
        if coeff != 1 { built.insert(.constant(coeff), at: 0) }
        return makeProduct(built)
    }

    // Rebuild a left-associated sum from an ordered term list.
    func makeSum(_ terms: [Component]) -> Component {
        guard let first = terms.first else { return .constant(0) }
        return terms.dropFirst().reduce(first) { .sum($0, $1) }
    }

    // Flatten a sum, fold its numeric part, and collect like terms by coefficient.
    func simplifySum(_ c: Component) -> Component {
        var constant = 0.0
        var groups: [(rest: Component, key: String, coeff: Double)] = []

        for raw in sumTerms(c) {
            for t in sumTerms(simp(raw)) {
                // Split the term into a numeric coefficient and the rest.
                var coeff = 1.0
                var rest: [Component] = []
                for f in productFactors(t) {
                    if case .constant(let v) = f { coeff *= v } else { rest.append(f) }
                }
                if rest.isEmpty { constant += coeff; continue }
                rest.sort { structureKey($0) < structureKey($1) }
                let restC = makeProduct(rest)
                let key = structureKey(restC)
                if let i = groups.firstIndex(where: { $0.key == key }) {
                    groups[i].coeff += coeff
                } else {
                    groups.append((restC, key, coeff))
                }
            }
        }

        var built: [Component] = []
        for g in groups {
            let co = fold(g.coeff)
            if co == 0 { continue }
            built.append(co == 1 ? g.rest : simp(.product(.constant(co), g.rest)))
        }
        built.sort { structureKey($0) < structureKey($1) }

        constant = fold(constant)
        if constant != 0 { built.append(.constant(constant)) }
        if built.isEmpty { return .constant(0) }
        return makeSum(built)
    }

    // One bottom-up pass: simplify children, then normalize at this node.
    func simp(_ c: Component) -> Component {
        switch c {
        case .variable:        return c
        case .constant(let v): return .constant(fold(v))
        case .sum:             return simplifySum(c)
        case .difference(let a, let b): return simplifySum(.sum(a, .product(b, .constant(-1))))
        case .product:         return simplifyProduct(c)
        case .quotient(let a, let b):        return simplifyProduct(.product(a, .power(b, .constant(-1))))
        case .power(let b, let e):
            return simplifyPower(simp(b), simp(e))
        case .ln(let arg):
            let a = simp(arg)
            if case .constant(let v) = a { return .constant(fold(log(v))) }
            return .ln(a)
        case .sin(let arg):
            let a = simp(arg)
            if case .constant(let v) = a { return .constant(fold(sin(v))) }
            return .sin(a)
        case .cos(let arg):
            let a = simp(arg)
            if case .constant(let v) = a { return .constant(fold(cos(v))) }
            return .cos(a)
        case .hole:
            return c
        }
    }

    // Iterate to a fixed point; the cap guards against any non-idempotent rule.
    var current = component
    for _ in 0..<100 {
        let next = simp(current)
        if next == current { return next }   // relies on Component: Equatable
        current = next
    }
    return current
}

///Returns nil if is positive, otherwise returns negated value,
func makeNegativePositive(_ c: Component) -> Component? {
    switch c {
    case .hole, .variable, .sin, .cos, .ln, .sum, .difference, .power: return nil
    case .product(let a, let b):
        let negatedA = makeNegativePositive(a)
        let negatedB = makeNegativePositive(b)
        if negatedA == nil && negatedB != nil {
            return .product(a, negatedB ?? .hole)
        } else if negatedA != nil && negatedB == nil {
            return .product(negatedA ?? .hole, b)
        } else {
            return nil
        }
    case .quotient(let a, let b):
        let negatedA = makeNegativePositive(a)
        let negatedB = makeNegativePositive(b)
        if negatedA == nil && negatedB != nil {
            return .quotient(a, negatedB ?? .hole)
        } else if negatedA != nil && negatedB == nil {
            return .quotient(negatedA ?? .hole, b)
        } else {
            return nil
        }
    case .constant(let a): return a < 0 ? .constant(-a) : nil
    }
}

///Uses division instead of a*b^-1
func rectifySimplifiedComponent(_ c: Component) -> Component {
    switch c {
    case .constant, .variable, .hole: return c
    case .sum(let a, let b):          return .sum(rectifySimplifiedComponent(a), rectifySimplifiedComponent(b))
    case .difference(let a, let b):   return .difference(rectifySimplifiedComponent(a), rectifySimplifiedComponent(b))
    case .sin(let a):                 return .sin(rectifySimplifiedComponent(a))
    case .cos(let a):                 return .cos(rectifySimplifiedComponent(a))
    case .ln(let a):                  return .ln(rectifySimplifiedComponent(a))
    case .power(let a, let b):
        let negatedExponent = makeNegativePositive(b)
        if let negative = negatedExponent {
            return .quotient(.constant(1), (negative == .constant(1)) ? a : .power(a, negative))
        } else {
            return c
        }
    case .product(let a, let b):
        var (nums, denoms) = collectNumeratorsDenominators(.product(rectifySimplifiedComponent(a), rectifySimplifiedComponent(b)))
        var currentNum: Component
        if nums.count > 0 {
            currentNum = nums.removeFirst()
            for i in nums {
                currentNum = .product(currentNum, i)
            }
        } else {
            currentNum = .constant(1)
        }
        
        guard denoms.count > 0 else {
            return currentNum
        }
        var currentDenom = denoms.removeFirst()
        for i in nums {
            currentDenom = .product(currentDenom, i)
        }
        
        return .quotient(currentNum, currentDenom)
    case .quotient(let a, let b):
        var (nums, denoms) = collectNumeratorsDenominators(.quotient(rectifySimplifiedComponent(a), rectifySimplifiedComponent(b)))
        var currentNum: Component
        if nums.count > 0 {
            currentNum = nums.removeFirst()
            for i in nums {
                currentNum = .product(currentNum, i)
            }
        } else {
            currentNum = .constant(1)
        }
        
        guard denoms.count > 0 else {
            return currentNum
        }
        var currentDenom = denoms.removeFirst()
        for i in nums {
            currentDenom = .product(currentDenom, i)
        }
        
        return .quotient(currentNum, currentDenom)
    }
    
    func collectNumeratorsDenominators(_ c: Component) -> ([Component], [Component]) {
        switch c {
        case .constant, .variable, .hole, .sum, .difference, .sin, .cos, .ln: return ([c], [])
        case .power(let a, let b):
            if let negatedB = makeNegativePositive(b) {
                print("\(textify(c)) power transferred to denom")
                return ([], [.power(a, negatedB)])
            } else {
                print("\(textify(c)) power released as is")
                return ([c], [])
            }
        case .product(let a, let b):
            var numerators = collectNumeratorsDenominators(a).0
            var denominators = collectNumeratorsDenominators(a).1
            numerators.append(contentsOf: collectNumeratorsDenominators(b).0)
            denominators.append(contentsOf: collectNumeratorsDenominators(b).1)
            return (numerators, denominators)
        case .quotient(let a, let b):
            var numerators = collectNumeratorsDenominators(a).0
            var denominators = collectNumeratorsDenominators(a).1
            numerators.append(contentsOf: collectNumeratorsDenominators(b).1)
            denominators.append(contentsOf: collectNumeratorsDenominators(b).0)
            var numeratorCoefficient: Double = 1
            var newNumerators: [Component] = []
            for (i, obj) in numerators.enumerated() {
                if case .constant(let a) = obj {
                    numeratorCoefficient *= a
                } else {
                    newNumerators.append(obj)
                }
            }
            if numeratorCoefficient != 1 {
                numerators.insert(.constant(numeratorCoefficient), at: 0)
            }
            return (numerators, denominators)
        }
    }
}
struct BetterAutoDifferentiateDemoView: View {
    @State private var xValue: Double = 2.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analytical Derivatives")
                .font(.title).bold()
            
            // Let's try f(x) = x^x
            let powx = Component.sum(.product(.variable, .variable), .product(.constant(-1), .power(.variable, .constant(2))))
            
            
            let expr = Expression("f(x)", directory: powx)
            let derivativeComponent = differentiate(expr.directory)
            let simplifiedDerivative = simplify(derivativeComponent)
            let derivativeExpr = Expression("f'(x)", directory: simplifiedDerivative)

            Group {
                Text("f(x) = \(textify(expr.directory))")
                Text("f'(x) = \(textify(derivativeComponent))")
                Text("Simplified: \(textify(simplifiedDerivative))")
                HStack {
                    Text("x =")
                    Slider(value: $xValue, in: -15...15, step: 0.01)
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
