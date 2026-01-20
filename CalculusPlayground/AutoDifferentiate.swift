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
            return Function( transform: { (<!>rhs)((<!>lhs)($0)) }, text: "(\(lhs.mathText!)) >>> (\(rhs.mathText!))", derivativeOrigin: <!>(derivative))
        } else {
            return Function() {
                (<!>rhs)((<!>lhs)($0))
            }
        }
    }
    //Adds two functions and creates derivative
    static func +(lhs: Function, rhs: Function) -> Function {
        if ???lhs != nil && ???rhs != nil {
            return Function( transform: { (<!>lhs)($0) * (<!>rhs)($0) }, text: "(\(lhs.mathText!)) + (\(rhs.mathText!))", derivativeOrigin: <!>((???lhs)! + (???rhs)!))
        } else {
            return Function() {
                (<!>lhs)($0) + (<!>rhs)($0)
            }
        }
    }
    //Multiplies to functions and creates derivative
    static func *(lhs: Function, rhs: Function) -> Function {
        if ???lhs != nil && ???rhs != nil {
            let derivative = (???lhs)! * rhs + (???rhs)! * lhs
            return Function( transform: { (<!>lhs)($0) * (<!>rhs)($0) }, text: "(\(lhs.mathText!)) * (\(rhs.mathText!))", derivativeOrigin: <!>derivative)
        } else {
            return Function() {
                (<!>lhs)($0) * (<!>rhs)($0)
            }
        }
    }
    static func functionExp(_ b: Function, _ e: Function) -> Function {
        return ((b >>> .naturalLog * e) >>> .exponential)
    }
    static func functionLog(_ b: Function, _ e: Function) -> Function {
        return b >>> .naturalLog * b >>> .naturalLog >>> .inverse
    }
} //End of submission

//Test
let fpx: Function = (???(Function.square * Function.sine >>> Function.naturalLog + Function.inverse))!
let realfpx: Function = Function { x in
    2*x*log(sin(x)) + pow(x, 2)*cos(x)*(1/sin(x)) + -1*pow(x, -2)
}
struct autodiffTestView: View {
    @State var x: Double = 0.0
    var body: some View {
        Text(((<!>fpx)(x)).description)
        Slider(value: $x, in: -10.0...10.0)
        Text(fpx.mathText!)
        Text(x.description)
        Text((<!>realfpx)(x).description)
    }
}

#Preview {
    autodiffTestView()
}
