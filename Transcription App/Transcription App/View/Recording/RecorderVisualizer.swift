import SwiftUI
import Combine
import AVFoundation

/// Displays audio level values as a horizontal bar graph waveform
struct RecorderVisualizer: View {
    // MARK: - Properties
    let values: [Float]
    let barCount: Int
    
    // MARK: - Configuration
    private let barSpacing: CGFloat = 1
    private let minBarHeight: CGFloat = 0.07
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            let width = max(0, geo.size.width.isFinite ? geo.size.width : 0)
            let height = max(0, geo.size.height.isFinite ? geo.size.height : 0)
            let safeBarCount = max(1, barCount)
            let barWidth = calculateBarWidth(width: width, barCount: safeBarCount)
            let barValues = calculateBarValues(barCount: safeBarCount)
            
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<safeBarCount, id: \.self) { index in
                    BarView(
                        value: barValues[index],
                        width: barWidth,
                        height: height,
                        minHeight: minBarHeight
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func calculateBarWidth(width: CGFloat, barCount: Int) -> CGFloat {
        let totalSpacing = CGFloat(barCount - 1) * barSpacing
        let availableWidth = max(0, width - totalSpacing)
        return availableWidth / CGFloat(barCount)
    }
    
    private func calculateBarValues(barCount: Int) -> [Float] {
        let chunkSize = max(1, values.count / barCount)
        
        return (0..<barCount).map { i in
            let start = i * chunkSize
            let end = min(start + chunkSize, values.count)
            
            guard start < end else { return 0 }
            
            let slice = values[start..<end]
            return slice.reduce(0, +) / Float(slice.count)
        }
    }
}

// MARK: - Bar View
private struct BarView: View {
    let value: Float
    let width: CGFloat
    let height: CGFloat
    let minHeight: CGFloat
    
    var body: some View {
        let normalizedValue = CGFloat(value.isFinite ? value : 0)
        let cappedValue = max(minHeight, min(normalizedValue, 1))
        let barHeight = max(0, min(height, cappedValue * height))
        let yOffset = (height - barHeight) / 2
        
        Rectangle()
            .fill(Color.primary.opacity(0.85))
            .frame(width: max(0, width), height: barHeight)
            .cornerRadius(width / 2)
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            .offset(y: yOffset)
    }
}
