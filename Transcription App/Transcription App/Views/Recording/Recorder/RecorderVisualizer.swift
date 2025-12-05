import SwiftUI
import Combine
import AVFoundation

struct RecorderVisualizer: View {
    let values: [Float]
    let barCount: Int
    
    private let barSpacing: CGFloat = 3
    private let minBarHeight: CGFloat = 0.04
    private let barWidth: CGFloat = 3
    
    var body: some View {
        GeometryReader { geo in
            let height = max(0, geo.size.height.isFinite ? geo.size.height : 0)
            
            // Always show exactly barCount bars, padding with zeros if needed
            let displayValues = paddedValues()
            
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(Array(displayValues.enumerated()), id: \.offset) { index, value in
                    BarView(
                        value: value,
                        width: barWidth,
                        height: height,
                        minHeight: minBarHeight
                    )
                    .id(values.count - displayValues.count + index) // Stable ID based on position in full array
                }
            }
        }
    }
    
    private func paddedValues() -> [Float] {
        let recent = Array(values.suffix(barCount))
        if recent.count < barCount {
            let padding = Array(repeating: Float(0), count: barCount - recent.count)
            return padding + recent
        }
        return recent
    }
}

private struct BarView: View {
    let value: Float
    let width: CGFloat
    let height: CGFloat
    let minHeight: CGFloat
    
    var body: some View {
        let normalizedValue = CGFloat(value.isFinite ? value : 0)
        let cappedValue = max(minHeight, min(normalizedValue, 1))
        let calculatedHeight = cappedValue * height
        let barHeight = max(0, min(height, calculatedHeight.isFinite ? calculatedHeight : 0))
        
        Rectangle()
            .fill(Color.accent)
            .frame(width: width.isFinite ? width : 0, height: barHeight.isFinite ? barHeight : 0)
            .cornerRadius(1.5)
            .frame(height: height.isFinite ? height : 0, alignment: .center)
    }
}
