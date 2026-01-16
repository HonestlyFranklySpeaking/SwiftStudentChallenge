import SwiftUI
import RangeSlider



struct RangeSliderModifier: ViewModifier {
    @Binding var range: ClosedRange<Double>
    var bounds: ClosedRange<Double>
    var step: Double = 1.0
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // The Track (passed as content)
                content
                    .opacity(0.3)
                
                // The Active Range Highlight
                Capsule()
                    .fill(Color.purple)
                    .frame(width: CGFloat((range.upperBound - range.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width + 30)
                    .offset(x: CGFloat((range.lowerBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width - 15)
                
                // Lower Thumb
                Thumb(value: $range, isLower: true, bounds: bounds, step: step, width: geometry.size.width)
                
                // Upper Thumb
                Thumb(value: $range, isLower: false, bounds: bounds, step: step, width: geometry.size.width)
            }
        }
        .frame(height: 30) // Standard slider height
    }
}

private struct Thumb: View {
    @Binding var value: ClosedRange<Double>
    let isLower: Bool
    let bounds: ClosedRange<Double>
    let step: Double
    let width: CGFloat
    
    private var currentPosition: CGFloat {
        let val = isLower ? value.lowerBound : value.upperBound
        return CGFloat((val - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * width
    }
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .shadow(radius: 2)
            .frame(width: 28, height: 28)
            .offset(x: currentPosition - 14)
            .gesture(
                DragGesture().onChanged { gesture in
                    let percent = Double(gesture.location.x / width)
                    let newValue = bounds.lowerBound + percent * (bounds.upperBound - bounds.lowerBound)
                    let steppedValue = (newValue / step).rounded() * step
                    let clampedValue = min(max(steppedValue, bounds.lowerBound), bounds.upperBound)
                    
                    if isLower {
                        value = min(clampedValue, value.upperBound - step)...value.upperBound
                    } else {
                        value = value.lowerBound...max(clampedValue, value.lowerBound + step)
                    }
                }
            )
    }
}

// Extension to make the syntax clean
extension View {
    func rangeSlider(range: Binding<ClosedRange<Double>>, in bounds: ClosedRange<Double>, step: Double = 1.0) -> some View {
        self.modifier(RangeSliderModifier(range: range, bounds: bounds, step: step))
    }
}



struct RangeSliderTest: View {
    @State private var priceRange = 20.0...80.0
    @State var upper: Double = 0.5
    @State var lower: Double = 0.5
    var body: some View {
        VStack {
            Text("From Github")
            Text("$\((priceRange.upperBound - priceRange.lowerBound) * lower + priceRange.lowerBound) - \((priceRange.upperBound - priceRange.lowerBound) * upper + priceRange.lowerBound)")
            RangeSlider(lowerValue: $lower, upperValue: $upper, step: 0.0001)
            Text("Price: $\(Int(priceRange.lowerBound)) - $\(Int(priceRange.upperBound))")
            
            // Apply the modifier to a simple Capsule to create the slider
            Capsule()
                .fill(Color.gray)
                .frame(height: 6)
                .rangeSlider(range: $priceRange, in: 0...100, step: 5)
                .padding()
        }
    }
}


#Preview {
    RangeSliderTest()
}
