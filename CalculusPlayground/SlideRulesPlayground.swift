//
//  LogRulesPlayground.swift
//  CalculusPlayground
//
//  Created by Timothy Qin on 21/1/26.
//
import SwiftUI
import Foundation

struct ruler1: View {
    @State var screenSize: CGSize
    @State private var offset = CGFloat.zero
    @State var positionOffset = CGFloat.zero
    var tickRange: Range<Int>
    var tick: AnyView
    var drag: some Gesture {
        DragGesture()
            .onChanged { a in
                offset = a.translation.width
            }
            .onEnded { a in
                positionOffset = positionOffset + offset
                offset = .zero
            }
    }
    
    func getOffset() -> Double {
        return (screenSize.width - 40) / log(10)
    }
    
    var ticks: some View {
        ZStack {
            ForEach(tickRange, id: \.self) { x in
                VStack {
                    Text(x.description)
                        .font(.caption2)
                    tick
                }
                .offset(CGSize(width: getOffset()*log(Double(x)), height: 0))
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                .foregroundStyle(.gray)
                .frame(height: 50, alignment: .center)
            ticks
        }
        
        .gesture(drag)
        .offset(CGSize(width: positionOffset + offset, height: 0))
    }
}

struct ruler2: View {
    @State var screenSize: CGSize
    @State private var offset = CGFloat.zero
    @State var positionOffset = CGFloat.zero
    var tickRange: Range<Int>
    var tick: AnyView
    
    func getOffset() -> Double {
        return (screenSize.width - 40) / log(10)
    }
    
    var ticks: some View {
        ZStack {
            ForEach(tickRange, id: \.self) { x in
                VStack {
                    tick
                    Text(x.description)
                        .font(.caption2)
                }
                .offset(CGSize(width: getOffset()*log(Double(x)), height: 0))
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                .foregroundStyle(.gray)
                .frame(height: 50, alignment: .center)
            ticks
        }
    }
}

struct SlideRulePlayground: View {
    var tick: some View {
        Rectangle()
            .foregroundStyle(.black)
            .frame(width: 1, height: 7)
    }
    let tickNum = 10
    let tickRange = 1..<11 as Range<Int>
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0.5) {
                ruler1(screenSize: geo.size, tickRange: tickRange, tick: AnyView(tick))
                ruler2(screenSize: geo.size, tickRange: tickRange, tick: AnyView(tick))
            }.padding(10.0)
        }
    }
    
}

#Preview {
    SlideRulePlayground()
}
