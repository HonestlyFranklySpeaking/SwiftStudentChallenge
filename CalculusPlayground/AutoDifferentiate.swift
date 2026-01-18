//
//  AutoIntegrate.swift
//  CalculusPlayground
//
//  Created by Timothy Qin on 17/1/26.
//
prefix operator ∂
infix operator ++: AdditionPrecedence
infix operator **: MultiplicationPrecedence
prefix operator †
infix operator >>>: BitwiseShiftPrecedence
infix operator >>>>: BitwiseShiftPrecedence

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
    static func ++(lhs: Function, rhs: Function) -> Function {
        return Function() { lhs.transform($0) + rhs.transform($0) }
    }
    static func **(lhs: Function, rhs: Function) -> Function {
        return Function() { lhs.transform($0) * rhs.transform($0) }
    }
    static func >>>(lhs: Function, rhs: Function) -> Function {
        return Function(transform: {lhs.transform(rhs.transform($0))}, text: "\(lhs.mathText!)(\(rhs.mathText!))", derivativeOrigin: †((∂rhs)! ** lhs >>>> (∂rhs)!))
    }
    static func +(lhs: Function, rhs: Function) -> Function {
        return Function( transform: { lhs.transform($0) * rhs.transform($0) }, text: "(\(lhs.mathText!)) + (\(rhs.mathText!))", derivativeOrigin: †((∂lhs)! ++ (∂rhs)!))
        
    }
    static func *(lhs: Function, rhs: Function) -> Function {
        return Function( transform: {
            lhs.transform($0) * rhs.transform($0)
        }, text: "(\(lhs.mathText!)) * (\(rhs.mathText!))", derivativeOrigin: †((∂lhs)! ** rhs ++ (∂rhs)! ** lhs))
    }
    
}
