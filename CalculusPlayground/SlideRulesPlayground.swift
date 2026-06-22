//
//  LogRulesPlayground.swift
//  CalculusPlayground
//
//  Created by Timothy Qin on 21/1/26.
//
import SwiftUI
import SwiftData
import Foundation

struct ruler1: View {
    let gradientStops: [Gradient.Stop]
    @Binding var screenSize: CGSize
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
                .foregroundStyle(LinearGradient(colors: [.teal, .blue], startPoint: .topTrailing, endPoint: .bottomLeading))
                .frame(height: 50, alignment: .center)
            ticks
        }
        
        .gesture(drag)
        .offset(CGSize(width: positionOffset + offset, height: 0))
    }
}

struct ruler2: View {
    let gradientStops: [Gradient.Stop]
    @Binding var screenSize: CGSize
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
                .foregroundStyle(LinearGradient(colors: [.blue, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
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
    
    ///Generates log gradient
    ///Looks super ugly so is overriden in ruler1 and 2
    ///But could be reimplemented?
    func logStops(from: Color, to: Color) -> [Gradient.Stop] {
        func intermediateColor(zero: UIColor, one: UIColor, at: Double) -> Color {
            var zeroRed: CGFloat = 0.0
            var zeroGreen: CGFloat = 0.0
            var zeroBlue: CGFloat = 0.0
            var oneRed: CGFloat = 0.0
            var oneGreen: CGFloat = 0.0
            var oneBlue: CGFloat = 0.0
            
            zero.getRed(&zeroRed, green: &zeroGreen, blue: &zeroBlue, alpha: nil)
            
            one.getRed(&oneRed, green: &oneGreen, blue: &oneBlue, alpha: nil)
            
            let redDifferance = oneRed - zeroRed
            let greenDifferance = oneGreen - zeroGreen
            let blueDifferance = oneBlue - zeroBlue
            return Color(red: zeroRed + (redDifferance) * at, green: zeroGreen + (greenDifferance) * at, blue: zeroBlue + (blueDifferance) * at)
        }
        return (0..<10 as Range<Int>).map { i in
            Gradient.Stop(color: intermediateColor(zero: UIColor(from), one: UIColor(to), at: Double((i)/9)), location: log(CGFloat(i+1))/log(10))
        }
    }
    @State var screenSize: CGSize = CGSize.zero
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0.5) {
                    ruler1(gradientStops: logStops(from: .blue, to: .teal), screenSize: $screenSize, tickRange: tickRange, tick: AnyView(tick))
                    ruler2(gradientStops: logStops(from: .blue, to: .teal), screenSize: $screenSize, tickRange: tickRange, tick: AnyView(tick))
                }
                .padding(10.0)
                .onChange(of: geo.size) {
                    screenSize = geo.size
                }
            }
            .navigationTitle("Interactive Slide Rules")
        }
        
    }
}

#Preview {
    SlideRulePlayground()
}
