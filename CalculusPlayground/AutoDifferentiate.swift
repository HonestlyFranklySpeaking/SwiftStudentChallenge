//
//  AutoIntegrate.swift
//  CalculusPlayground
//
//  Created by Timothy Qin on 17/1/26.
//
import SwiftUI

//Takes the derivative
prefix operator ∂

//Adds two Functions, but doesn't create a new derivative
infix operator ++: AdditionPrecedence

//Same as above, with multiplication
infix operator **: MultiplicationPrecedence

//Finds Function.transform
prefix operator †

// a >>> b is a(b())
infix operator >>>: BitwiseShiftPrecedence

//Same as ** and ++ but with >>>
infix operator >>>>: BitwiseShiftPrecedence

infix operator <<<: BitwiseShiftPrecedence

extension Function {
    static prefix func †(_ x: Function) -> ((Double) -> Double) {
        return x.transform
    }
    static prefix func ∂(_ x: Function) -> Function? {
        return x.derivative
    }
    static func >>>>(lhs: Function, rhs: Function) -> Function {
        return Function() {
            (†lhs)((†rhs)($0))
        }
    }
    static func <<<(lhs: Function, rhs: Function) -> Function {
        return rhs >>> lhs
    }
    static func ++(lhs: Function, rhs: Function) -> Function {
        return Function() { lhs.transform($0) + rhs.transform($0) }
    }
    static func **(lhs: Function, rhs: Function) -> Function {
        return Function() { lhs.transform($0) * rhs.transform($0) }
    }
    
    static func >>>(lhs: Function, rhs: Function) -> Function {
        if ∂lhs != nil && ∂rhs != nil {
            return Function( transform: { lhs.transform($0) * rhs.transform($0) }, text: "(\(lhs.mathText!)) >>> (\(rhs.mathText!))", derivativeOrigin: †((∂lhs)! ** lhs >>>> (∂rhs)!))
        } else {
            return Function() {
                lhs.transform($0) * rhs.transform($0)
            }
        }
        
    }
    static func +(lhs: Function, rhs: Function) -> Function {
        if ∂lhs != nil && ∂rhs != nil {
            return Function( transform: { lhs.transform($0) * rhs.transform($0) }, text: "(\(lhs.mathText!)) + (\(rhs.mathText!))", derivativeOrigin: †((∂lhs)! ++ (∂rhs)!))
        } else {
            return Function() {
                lhs.transform($0) * rhs.transform($0)
            }
        }
        
    }
    static func *(lhs: Function, rhs: Function) -> Function {
        if ∂lhs != nil && ∂rhs != nil {
            return Function( transform: { lhs.transform($0) * rhs.transform($0) }, text: "(\(lhs.mathText!)) * (\(rhs.mathText!))", derivativeOrigin: †((∂lhs)! ++ (∂rhs)!))
        } else {
            return Function() {
                lhs.transform($0) * rhs.transform($0)
            }
        }
        
    }
    
}

let fpx: Function = (∂(Function.sine >>> Function.square))!
let realfpx: Function = Function {
    
}
struct view: View {
    @State var x: Double = 0.0
    var body: some View {
        Text(((†fpx)(x)).description)
        Slider(value: $x, in: -10.0...10.0)
        Text(x.description)
    }
}

#Preview {
    view()
}
