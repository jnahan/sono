import SwiftUI

struct DragHandle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.warmGray300)
            .frame(width: 48, height: 4)
    }
}
