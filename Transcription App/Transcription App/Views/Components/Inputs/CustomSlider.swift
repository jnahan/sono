import SwiftUI

struct CustomSlider: View {
    @Binding var value: TimeInterval
    let range: ClosedRange<TimeInterval>
    var onEditingChanged: (Bool) -> Void = { _ in }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.blueGray300)
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Progress track
                Rectangle()
                    .fill(Color.baseBlack)
                    .frame(width: max(0, thumbPosition(in: geometry.size.width)), height: 4)
                    .cornerRadius(2)
                
                // Thumb
                Circle()
                    .fill(Color.baseBlack)
                    .frame(width: 8, height: 8)
                    .offset(x: thumbPosition(in: geometry.size.width) - 4) // Center the thumb
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                onEditingChanged(true)
                                updateValue(from: gesture.location.x, in: geometry.size.width)
                            }
                            .onEnded { _ in
                                onEditingChanged(false)
                            }
                    )
            }
            .frame(height: 8) // Ensure enough space for the thumb
            .contentShape(Rectangle()) // Make entire area tappable
            .onTapGesture { location in
                updateValue(from: location.x, in: geometry.size.width)
            }
        }
        .frame(height: 8)
    }
    
    private func thumbPosition(in width: CGFloat) -> CGFloat {
        guard width > 0, range.upperBound > range.lowerBound else { return 0 }
        let rangeSize = range.upperBound - range.lowerBound
        let percentage = (value - range.lowerBound) / rangeSize
        let clampedPercentage = max(0, min(1, percentage))
        let position = width * CGFloat(clampedPercentage)
        return position.isFinite ? position : 0
    }
    
    private func updateValue(from xPosition: CGFloat, in width: CGFloat) {
        guard width > 0, range.upperBound > range.lowerBound else { return }
        let percentage = max(0, min(1, xPosition / width))
        guard percentage.isFinite else { return }
        let rangeSize = range.upperBound - range.lowerBound
        let newValue = range.lowerBound + rangeSize * TimeInterval(percentage)
        guard newValue.isFinite else { return }
        value = newValue
    }
}
