//
//  AutoIntegrate.swift
//  CalculusPlayground
//
//  Created by Timothy Qin on 17/1/26.
//
import SwiftUI


precedencegroup CompositionPrecedence {
    higherThan: MultiplicationPrecedence
}


//Takes the derivative
prefix operator ∂

//Adds two Functions, but doesn't create a new derivative
infix operator ++: AdditionPrecedence

//Same as above, with multiplication
infix operator **: MultiplicationPrecedence

//Finds Function.transform
prefix operator †

// a >>> b is a(b())
infix operator >>>: CompositionPrecedence

//Same as ** and ++ but with >>>
infix operator >>>>: CompositionPrecedence

infix operator <<<: CompositionPrecedence

extension Function {
    static prefix func †(_ x: Function) -> ((Double) -> Double) {
        return x.transform
    }
    static prefix func ∂(_ x: Function) -> Function? {
        return x.derivative
    }
    static func >>>>(lhs: Function, rhs: Function) -> Function {
        return Function() {
            (†rhs)((†lhs)($0))
        }
    }
    static func <<<(lhs: Function, rhs: Function) -> Function {
        return rhs >>> lhs
    }
    static func ++(lhs: Function, rhs: Function) -> Function {
        return Function() { (†lhs)($0) + (†rhs)($0) }
    }

    
    static func >>>(lhs: Function, rhs: Function) -> Function {
        if ∂lhs != nil && ∂rhs != nil {
            let derivative = (∂lhs)! * lhs >>>> (∂rhs)!
            return Function( transform: { (†rhs)((†lhs)($0)) }, text: "(\(lhs.mathText!)) >>> (\(rhs.mathText!))", derivativeOrigin: †(derivative))
        } else {
            return Function() {
                (†rhs)((†lhs)($0))
            }
        }
        
    }
    static func +(lhs: Function, rhs: Function) -> Function {
        if ∂lhs != nil && ∂rhs != nil {
            return Function( transform: { (†lhs)($0) * (†rhs)($0) }, text: "(\(lhs.mathText!)) + (\(rhs.mathText!))", derivativeOrigin: †((∂lhs)! ++ (∂rhs)!))
        } else {
            return Function() {
                (†lhs)($0) * (†rhs)($0)
            }
        }
        
    }
    static func *(lhs: Function, rhs: Function) -> Function {
        if ∂lhs != nil && ∂rhs != nil {
            let derivative = (∂lhs)! * rhs ++ (∂rhs)! * lhs
            return Function( transform: { (†lhs)($0) * (†rhs)($0) }, text: "(\(lhs.mathText!)) * (\(rhs.mathText!))", derivativeOrigin: †derivative)
        } else {
            return Function() {
                (†lhs)($0) * (†rhs)($0)
            }
        }
        
    }
    
}


let fpx: Function = (∂(Function.square * Function.sine >>> Function.naturalLog + Function.inverse))!
let realfpx: Function = Function { x in
    2*x*log(sin(x)) + pow(x, 2)*cos(x)*(1/sin(x)) + -1*pow(x, -2)
}
struct autodiffTestView: View {
    @State var x: Double = 0.0
    var body: some View {
        Text(((†fpx)(x)).description)
        Slider(value: $x, in: -10.0...10.0)
        Text(x.description)
        Text((†realfpx)(x).description)
    }
}

#Preview {
    autodiffTestView()
}
