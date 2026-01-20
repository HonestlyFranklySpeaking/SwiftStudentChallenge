//
//  AutoIntegrate.swift
//  CalculusPlayground
//
//  Created by Timothy Qin on 17/1/26.
//
import SwiftUI
import Swift

precedencegroup ReverseCompositionPrecedence {
    associativity: right
    higherThan: MultiplicationPrecedence
}

precedencegroup CompositionPrecedence {
    associativity: left
    higherThan: MultiplicationPrecedence
}

//Takes the derivative
prefix operator ???
//Finds Function.transform
prefix operator <!>
// a >>> b is a(b()), and <<< is the same thing backwards, and it also defines the derivative if possible
infix operator >>>: CompositionPrecedence
infix operator <<<: ReverseCompositionPrecedence
///Adds support for autodiff operations
extension Function {
    ///Fetches _.transform
    static prefix func <!>(_ x: Function) -> ((Double) -> Double) {
        return x.transform
    }
    ///Fetches _.derivative
    static prefix func ???(_ x: Function) -> Function? {
        return x.derivative
    }
    //See operator definition; prevents indefinite recursion because derivative functions have a nil derivative, triggering else block
    static func <<<(lhs: Function, rhs: Function) -> Function {
        return rhs >>> lhs
    }
    static func >>>(lhs: Function, rhs: Function) -> Function {
        if ???lhs != nil && ???rhs != nil {
            let derivative = (???lhs)! * lhs >>> (???rhs)!
            return Function( transform: { (<!>rhs)((<!>lhs)($0)) }, text: "(\(lhs.mathText!)) >>> (\(rhs.mathText!))", derivativeText: "(\((???lhs)!.mathText!)) * (\(lhs.mathText!)) >>> (\(((???rhs)!.mathText!)))", derivativeOrigin: <!>(derivative))
        } else {
            return Function(transform: {
                (<!>rhs)((<!>lhs)($0))
            }, text: "(\(lhs.mathText!)) >>> (\(rhs.mathText!))")
        }
    }
    //Adds two functions and creates derivative
    static func +(lhs: Function, rhs: Function) -> Function {
        if ???lhs != nil && ???rhs != nil {
            return Function( transform: { (<!>lhs)($0) * (<!>rhs)($0) }, text: "(\(lhs.mathText!)) + (\(rhs.mathText!))", derivativeText: "(\((???lhs)!.mathText!)) + (\((???rhs)!.mathText!))", derivativeOrigin: <!>((???lhs)! + (???rhs)!))
        } else {
            return Function(transform: {
                (<!>lhs)($0) + (<!>rhs)($0)
            }, text: "(\(lhs.mathText!)) + (\(rhs.mathText!))")
        }
    }
    //Multiplies to functions and creates derivative
    static func *(lhs: Function, rhs: Function) -> Function {
        if ???lhs != nil && ???rhs != nil {
            let derivative = (???lhs)! * rhs + (???rhs)! * lhs
            return Function( transform: { (<!>lhs)($0) * (<!>rhs)($0) }, text: "(\(lhs.mathText!)) * (\(rhs.mathText!))", derivativeText: "(\(lhs.mathText!)) * (\((???rhs)!.mathText!)) + (\(rhs.mathText!)) * (\((???rhs)!.mathText!))",  derivativeOrigin: <!>derivative)
        } else {
            return Function(transform: {
                (<!>lhs)($0) * (<!>rhs)($0)
            }, text: "(\(lhs.mathText!)) * (\(rhs.mathText!))")
        }
    }
    static func functionExp(_ b: Function, _ e: Function) -> Function {
        return ((b >>> .naturalLog * e) >>> .exp)
    }
    static func functionLog(_ b: Function, _ e: Function) -> Function {
        return b >>> .naturalLog * b >>> .naturalLog >>> .inverse
    }
    static func constant(_ n: Double) -> Function {
        return Function(transform: ({_ in n} as ((Double) -> Double)), text: n.description, derivativeText: "0", derivativeOrigin: {_ in 0} as ((Double) -> Double))
    }
} //End of submission

//Test
let fpx: Function = (???(Function.functionExp( Function.identity, Function.constant(2))))!
let realfpx: Function = Function { x in
    2 * x
}
struct autodiffTestView: View {
    @State var x: Double = 0.0
    var body: some View {
        Text(((<!>fpx)(x)).description)
        Slider(value: $x, in: -10.0...10.0)
        Text(fpx.mathText ?? "No text")
        Text(x.description)
        Text((<!>realfpx)(x).description)
    }
}


#Preview {
    autodiffTestView()
}
