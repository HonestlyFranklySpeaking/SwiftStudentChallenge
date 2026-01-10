//
//  Guage.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 9/1/26.
//

import SwiftUI

struct GaugeDemoView: View {
    @State private var currentValue: Double = 125.0
    
    let minValue: Double = 0.0
    let maxValue: Double = 251.0
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Content")
            }
            .navigationTitle("Gauge Demo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Text("Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                      
                        Gauge(value: currentValue, in: minValue...maxValue) {
                            
                        }
                        .gaugeStyle(ToolbarGauge())
                        .tint(.red)
                        .frame(width: 34, height: 34)
                    }
                }
            }
        }
    }
}

#Preview {
    GaugeDemoView()
}


struct ToolbarGauge: GaugeStyle {
    var strokeWidth: CGFloat = 4.5
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {

            Circle()
                .stroke(Color(.systemGray5), lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: configuration.value)
                .stroke(
                    configuration.label != nil ? .red : .primary,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 24, height: 24)
    }
}
