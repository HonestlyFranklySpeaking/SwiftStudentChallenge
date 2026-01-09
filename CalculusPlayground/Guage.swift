//
//  Guage.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 9/1/26.
//

import SwiftUI

struct GaugeDemoView: View {
    // Example state variable for the gauge value, adjust as needed
    @State private var currentValue: Double = 125.0
    let minValue: Double = 0.0
    let maxValue: Double = 251.0
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Your Main Content")
            }
            .navigationTitle("Gauge Demo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { // Adjust placement as needed
                    // Use an HStack to place the label to the left of the gauge
                    HStack(spacing: 8) {
                        Text("Value") // The label
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // The circular gauge
                        Gauge(value: currentValue, in: minValue...maxValue) {
                            // Empty label, as we have a custom one in the HStack
                        }
                        .gaugeStyle(ToolbarGauge())
                        .tint(.red)
                        .frame(width: 34, height: 34)// Control the size for a toolbar fit
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
    var strokeWidth: CGFloat = 4.5 // Adjust this value for ring thickness

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // 1. Background Track
            Circle()
                .stroke(Color(.systemGray5), lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: configuration.value) // configuration.value is normalized 0.0 to 1.0
                .stroke(
                    configuration.label != nil ? .red : .primary, // Uses tint or primary
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90)) // Starts progress at the top
        }
        .frame(width: 24, height: 24) // Keeps it standard toolbar size
    }
}
