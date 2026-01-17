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
                    .fill(Color.purple.opacity(0.4))
                    .glassEffect()
                    .frame(width: CGFloat((range.upperBound - range.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width + 30, height: 30)
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
            .glassEffect()
            .shadow(radius: 2)
            .frame(width: 20, height: 20)
            .offset(x: currentPosition - 10)
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
    let slideDomain: ClosedRange<Double> = 0.0 ... 100.0
    
    var body: some View {
        VStack {
            Capsule()
                .fill(Color.gray)
                .frame(height: 6)
                .rangeSlider(range: $priceRange, in: slideDomain, step: 5)
                .padding()
        }
    }
}


#Preview {
    RangeSliderTest()
}
