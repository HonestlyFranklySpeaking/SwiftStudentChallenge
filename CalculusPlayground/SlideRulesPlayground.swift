//
//  LogRulesPlayground.swift
//  CalculusPlayground
//
//  Created by Timothy Qin on 21/1/26.
//
import SwiftUI
import Foundation

struct SlideRulePlayground: View {
    var tick: some View {
        Rectangle()
            .foregroundStyle(.black)
            .frame(width: 1, height: 7)
    }
    let tickNum = 10
    let tickRange = 1..<11 as Range<Int>
    
    var ruler1: some View {
        VStack {
            Text(Helpers.shared.getScreenBounds().width.description)
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .foregroundStyle(.gray)
                    .frame(width: Helpers.shared.getScreenBounds().width, height: 50, alignment: .center)
                ZStack {
                    ForEach(tickRange) { x in
                        VStack {
                            Text(x.description)
                                .font(.caption2)
                            tick
                        }
                        .offset(CGSize(width: 160*log(Double(x)), height: 0))
                    }
                }
            }
            
        }
    }
    var ruler2: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                .foregroundStyle(.gray)
                .frame(width: Helpers.shared.getScreenBounds().width, height: 50, alignment: .center)
            ZStack {
                ForEach(tickRange) { x in
                    VStack {
                        tick
                        Text(x.description)
                            .font(.caption2)
                    }
                    .offset(CGSize(width: 160*log(Double(x)), height: 0))
                }
            }
        }
    }
    var body: some View {
        VStack(spacing: 0.2) {
            ruler1
            ruler2
        }
    }
    
}

#Preview {
    SlideRulePlayground()
}
